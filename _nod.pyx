from enum import Enum
from typing import Tuple, Optional, Callable
from contextlib import contextmanager

import cython
from cython.operator cimport dereference, preincrement
from cpython.bytes cimport PyBytes_FromStringAndSize, PyBytes_AsString
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
    registerLogvisorToExceptionConverter,
    removeLogvisorToExceptionConverter,
    _handleNativeException,
    checkException,
)


cdef string _str_to_string(str path):
    return path.encode("utf-8")


cdef str _view_to_str(c_string_view str_view):
    return PyBytes_FromStringAndSize(str_view.data(), str_view.size()).decode("utf-8")


ProgressCallback = Callable[[float, str, int], None]


cdef void invoke_callback_function(object callback, const string& a, float progress) except *:
    callback(a.decode("utf-8"), progress)


cdef void invoke_fprogress_function(object callback, float totalProg, const string& fileName, size_t fileBytesXfered) except *:
    callback(totalProg, fileName.decode("utf-8"), fileBytesXfered)


@contextmanager
def _log_exception_handler():
    registerLogvisorToExceptionConverter()
    yield
    removeLogvisorToExceptionConverter()


cdef class Header:
    @staticmethod
    cdef create(const c_Header& h):
        self = Header()
        self.game_id = PyBytes_FromStringAndSize(h.m_gameID, 6)
        self.disc_num = h.m_discNum
        self.disc_version = h.m_discVersion
        self.audio_streaming = h.m_audioStreaming
        self.stream_buf_sz = h.m_streamBufSz
        self.wii_magic = h.m_wiiMagic
        self.gcn_magic = h.m_gcnMagic
        self.game_title = PyBytes_FromStringAndSize(h.m_gameTitle, 64)
        self.disable_hash_verification = h.m_disableHashVerification
        self.disable_disc_enc = h.m_disableDiscEnc
        self.debug_mon_off = h.m_debugMonOff
        self.debug_load_addr = h.m_debugLoadAddr
        self.dol_off = h.m_dolOff
        self.fst_off = h.m_fstOff
        self.fst_sz = h.m_fstSz
        self.fst_max_sz = h.m_fstMaxSz
        self.fst_memory_address = h.m_fstMemoryAddress
        self.user_position = h.m_userPosition
        self.user_sz = h.m_userSz


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
    cdef int offset

    @staticmethod
    cdef create(unique_ptr[c_IPartReadStream] c_stream):
        stream = PartReadStream()
        stream.c_stream = move(c_stream)
        stream.offset = stream.c_stream.get().position()
        return stream

    def read(self, length):
        buf = PyBytes_FromStringAndSize(NULL, length)
        self.c_stream.get().read(PyBytes_AsString(buf), length)
        return buf

    def seek(self, offset, whence):
        if whence == 0:
            offset += self.offset
        self.c_stream.get().seek(offset, whence)
    
    def tell(self):
        return self.c_stream.get().position() - self.offset


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
        while f.value() != node.end():
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

    def get_header(self):
        return Header.create(self.c_partition.getHeader())

    def extract_to_directory(self, path: str, context: ExtractionContext) -> None:
        def work():
            with _log_exception_handler():
                extraction_successful = self.c_partition.extractToDirectory(
                    _str_to_string(path),
                    context.c_context
                )
            if not extraction_successful:
                raise RuntimeError("Unable to extract")
        return _handleNativeException(work)

    def files(self):
        cdef Node* node = &self.c_partition.getFSTRoot()
        result = []
        _files_for(dereference(node), "", result)
        return result


    def read_file(self, path: str, offset: int = 0):
        cdef Node* node = &self.c_partition.getFSTRoot()
        cdef c_optional[Node.DirectoryIterator] f

        for part in path.split("/"):
            f = node.find(_str_to_string(part))
            if f.value() != node.end():
                node = &dereference(dereference(f))
            else:
                raise Exception(f"File {part} not found in '{_view_to_str(node.getName())}'")
            
        return PartReadStream.create(dereference(dereference(f)).beginReadStream(offset))


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

    def __init__(self, out_path: str, progress_callback: ProgressCallback):
        pass

    def __cinit__(self, out_path: str, progress_callback: ProgressCallback):
        self.c_builder = new c_DiscBuilderGCN(_str_to_string(out_path),
                                              createFProgressFunction(progress_callback, invoke_fprogress_function))

    def __dealloc__(self):
        del self.c_builder

    def build_from_directory(self, directory_in: str) -> None:
        def work():
            with _log_exception_handler():
                self.c_builder.buildFromDirectory(_str_to_string(directory_in))
        return _handleNativeException(work)

    @staticmethod
    def calculate_total_size_required(directory_in: str) -> Optional[int]:
        size = c_DiscBuilderGCN.CalculateTotalSizeRequired(_str_to_string(directory_in))
        if size:
            return cython.operator.dereference(size)

        return None


def open_disc_from_image(path: str) -> Optional[Tuple[DiscBase, bool]]:
    def work():
        disc = DiscBase()
        cdef c_bool is_wii = True

        with _log_exception_handler():
            disc.c_disc = OpenDiscFromImage(_str_to_string(path), is_wii)
            checkException()
            return disc, is_wii

    return _handleNativeException(work)
