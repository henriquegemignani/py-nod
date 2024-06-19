import os
from enum import Enum
from typing import Tuple, Optional, Callable, List
from contextlib import contextmanager

import cython
from cython.operator cimport dereference, preincrement
from cpython.bytes cimport PyBytes_FromStringAndSize, PyBytes_AsString
from libc.stdint cimport uint64_t
from libcpp cimport bool as c_bool
from libcpp.string cimport string
from libcpp.memory cimport unique_ptr
from libcpp.utility cimport move

from nod_wrap cimport (
    optional as c_optional,
    string_view as c_string_view,

    ExtractionContext as c_ExtractionContext,
    createProgressCallbackFunction,
    getDol as _getDol,
    DiscBase as c_DiscBase,
    Header as c_Header,
    Kind_File,
    IPartReadStream as c_IPartReadStream,
    OpenDiscFromImage,
    DiscBuilderGCN as c_DiscBuilderGCN,
    createFProgressFunction,
    Node,
    EBuildResult,
    EBuildResult_Success,
    EBuildResult_Failed,
    EBuildResult_DiskFull,
    _handleNativeException,
    checkException,
)

import nod.types


cdef string _str_to_string(str path):
    return path.encode("utf-8")


cdef str _view_to_str(c_string_view str_view):
    return PyBytes_FromStringAndSize(str_view.data(), str_view.size()).decode("utf-8")


ProgressCallback = Callable[[float, str, int], None]


cdef void invoke_callback_function(object callback, const string& a, float progress) except *:
    callback(a.decode("utf-8"), progress)


cdef void invoke_fprogress_function(object callback, float totalProg, const string& fileName, size_t fileBytesXfered) except *:
    callback(totalProg, fileName.decode("utf-8"), fileBytesXfered)


cdef _create_dol_header(const c_Header& h):
    return nod.types.DolHeader(
        game_id = PyBytes_FromStringAndSize(h.m_gameID, 6),
        disc_num = h.m_discNum,
        disc_version = h.m_discVersion,
        audio_streaming = h.m_audioStreaming,
        stream_buf_sz = h.m_streamBufSz,
        wii_magic = h.m_wiiMagic,
        gcn_magic = h.m_gcnMagic,
        game_title = PyBytes_FromStringAndSize(h.m_gameTitle, 64),
        disable_hash_verification = h.m_disableHashVerification,
        disable_disc_enc = h.m_disableDiscEnc,
        debug_mon_off = h.m_debugMonOff,
        debug_load_addr = h.m_debugLoadAddr,
        dol_off = h.m_dolOff,
        fst_off = h.m_fstOff,
        fst_sz = h.m_fstSz,
        fst_max_sz = h.m_fstMaxSz,
        fst_memory_address = h.m_fstMemoryAddress,
        user_position = h.m_userPosition,
        user_sz = h.m_userSz,
    )


cdef class ExtractionContext:
    cdef c_ExtractionContext c_context

    def __cinit__(self):
        self.c_context = c_ExtractionContext()

    @property
    def force(self):
        return self.c_context.force

    @force.setter
    def force(self, value):
        self.c_context.force = value

    def set_progress_callback(self, callback):
        self.c_context.progressCB = createProgressCallbackFunction(callback, invoke_callback_function)


cdef class PartReadStream:
    cdef unique_ptr[c_IPartReadStream] c_stream
    cdef uint64_t offset
    cdef uint64_t _size

    @staticmethod
    cdef create(unique_ptr[c_IPartReadStream] c_stream, uint64_t size):
        stream = PartReadStream()
        stream.c_stream = move(c_stream)
        stream.offset = stream.c_stream.get().position()
        stream._size = size
        return stream

    def read(self, length=None):
        if not self.c_stream:
            raise RuntimeError("already closed")

        cdef uint64_t actual_length
        if length is None:
            actual_length = self._size - self.tell()
        else:
            actual_length = length

        buf = PyBytes_FromStringAndSize(NULL, actual_length)
        buf_as_str = PyBytes_AsString(buf)
        with nogil:
            self.c_stream.get().read(buf_as_str, actual_length)
        
        return buf

    def seek(self, offset, whence=0):
        if not self.c_stream:
            raise RuntimeError("already closed")
        if whence == 0:
            offset += self.offset
        elif whence == 2:
            offset += self._size
        elif whence != 1:
            raise ValueError(f"Unknown whence: {whence}")
        self.c_stream.get().seek(offset, whence)
    
    def tell(self):
        if not self.c_stream:
            raise RuntimeError("already closed")
        return self.c_stream.get().position() - self.offset

    def close(self):
        self.c_stream.reset()

    def size(self):
        return self._size

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()


cdef _files_for(Node& node, prefix: str, result: list):
    cdef c_optional[Node.DirectoryIterator] f

    name = _view_to_str(node.getName())
    if node.getKind() == Kind_File:
        result.append(prefix + name)
    else:
        newPrefix = prefix
        if name:
            newPrefix = prefix + name + "/"
        f = node.begin()
        while dereference(f) != node.end():
            _files_for(dereference(dereference(f)), newPrefix, result)
            preincrement(dereference(f))


cdef class Partition:
    cdef c_DiscBase.IPartition* c_partition
    cdef object discParent

    def __init__(self, parent):
        self.discParent = parent

    @staticmethod
    cdef create(c_DiscBase.IPartition* c_partition, object parent):
        partition = Partition(parent)
        partition.c_partition = c_partition
        return partition

    def get_dol(self) -> bytes:
        return _getDol(self.c_partition)

    def get_header(self) -> nod.types.DolHeader:
        return _create_dol_header(self.c_partition.getHeader())

    def extract_to_directory(self, path: str, context: ExtractionContext) -> None:
        def work():
            cdef c_bool extraction_successful = False
            cdef string native_path = _str_to_string(path)

            with nogil:
                extraction_successful = self.c_partition.extractToDirectory(
                    native_path,
                    context.c_context
                )
            if not extraction_successful:
                raise RuntimeError("Unable to extract")
        return _handleNativeException(work)

    def files(self) -> List[str]:
        cdef Node* node = &self.c_partition.getFSTRoot()
        result = []
        _files_for(dereference(node), "", result)
        return result


    def read_file(self, path: str, offset: int = 0) -> PartReadStream:
        cdef Node* node = &self.c_partition.getFSTRoot()
        cdef c_optional[Node.DirectoryIterator] f

        for part in path.split("/"):
            f = node.find(_str_to_string(part))
            if dereference(f) != node.end():
                node = &dereference(dereference(f))
            else:
                raise FileNotFoundError(f"File {part} not found in '{_view_to_str(node.getName())}'")
            
        return PartReadStream.create(
            dereference(dereference(f)).beginReadStream(offset),
            dereference(dereference(f)).size(),
        )


cdef class DiscBase:
    cdef unique_ptr[c_DiscBase] c_disc

    def get_data_partition(self) -> Optional[Partition]:
        cdef c_DiscBase.IPartition*partition = self.c_disc.get().getDataPartition()
        if partition:
            return Partition.create(partition, self)
        else:
            return None


cdef class DiscBuilderGCN:
    cdef c_DiscBuilderGCN* c_builder

    def __init__(self, out_path: os.PathLike, progress_callback: ProgressCallback):
        pass

    def __cinit__(self, out_path: os.PathLike, progress_callback: ProgressCallback):
        self.c_builder = new c_DiscBuilderGCN(_str_to_string(os.fspath(out_path)),
                                              createFProgressFunction(progress_callback, invoke_fprogress_function))

    def __dealloc__(self):
        del self.c_builder

    def build_from_directory(self, directory_in: os.PathLike) -> None:
        def work():
            cdef string native_path = _str_to_string(os.fspath(directory_in))
            with nogil:
                self.c_builder.buildFromDirectory(native_path)
        return _handleNativeException(work)

    @staticmethod
    def calculate_total_size_required(directory_in: os.PathLike) -> Optional[int]:
        cdef string native_path = _str_to_string(os.fspath(directory_in))

        cdef c_optional[uint64_t] size
        with nogil:
            size = c_DiscBuilderGCN.CalculateTotalSizeRequired(native_path)
        
        if size:
            return cython.operator.dereference(size)
        return None


def open_disc_from_image(path: os.PathLike) -> Tuple[DiscBase, bool]:
    def work():
        disc = DiscBase()
        cdef string native_path = _str_to_string(os.fspath(path))
        cdef c_bool is_wii = True

        with nogil:
            disc.c_disc = OpenDiscFromImage(native_path, is_wii)
        checkException()
        return disc, is_wii

    return _handleNativeException(work)
