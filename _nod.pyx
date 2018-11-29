from enum import Enum
from typing import Tuple, Optional, Callable
from contextlib import contextmanager

import cython
from libcpp cimport bool as c_bool
from libcpp.string cimport string
from libcpp.memory cimport unique_ptr

from nod_wrap cimport ExtractionContext as c_ExtractionContext, \
    createProgressCallbackFunction, DiscBase as c_DiscBase, \
    string_view, \
    OpenDiscFromImage, SystemStringView, SystemUTF8Conv, SystemString, SystemStringConv, \
    DiscBuilderGCN as c_DiscBuilderGCN, createFProgressFunction, EBuildResult,\
    EBuildResult_Success, EBuildResult_Failed, EBuildResult_DiskFull, string_to_system_string, \
    registerLogvisorToExceptionConverter, removeLogvisorToExceptionConverter, _handleNativeException, checkException

cdef SystemString _str_to_system_string(str path):
    return string_to_system_string(path.encode("utf-8"))

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

cdef class Partition:
    cdef c_DiscBase.IPartition*c_partition

    @staticmethod
    cdef create(c_DiscBase.IPartition* c_partition):
        partition = Partition()
        partition.c_partition = c_partition
        return partition

    def extract_to_directory(self, path: str, context: ExtractionContext) -> None:
        def work():
            cdef SystemString system_string = _str_to_system_string(path)
            with _log_exception_handler():
                extraction_successful = self.c_partition.extractToDirectory(
                    SystemStringView(system_string.c_str()),
                    context.c_context
                )
            if not extraction_successful:
                raise RuntimeError("Unable to extract")
        return _handleNativeException(work)

cdef class DiscBase:
    cdef unique_ptr[c_DiscBase] c_disc

    def get_data_partition(self) -> Optional[Partition]:
        cdef c_DiscBase.IPartition*partition = self.c_disc.get().getDataPartition()
        if partition:
            return Partition.create(partition)
        else:
            return None


cdef class DiscBuilderGCN:
    cdef c_DiscBuilderGCN* c_builder

    def __init__(self, out_path: str, progress_callback: ProgressCallback):
        pass

    def __cinit__(self, out_path: str, progress_callback: ProgressCallback):
        cdef SystemString system_string = _str_to_system_string(out_path)
        self.c_builder = new c_DiscBuilderGCN(SystemStringView(system_string.c_str()),
                                              createFProgressFunction(progress_callback, invoke_fprogress_function))

    def __dealloc__(self):
        del self.c_builder

    def build_from_directory(self, directory_in: str) -> None:
        def work():
            cdef SystemString system_string = _str_to_system_string(directory_in)
            with _log_exception_handler():
                self.c_builder.buildFromDirectory(SystemStringView(system_string.c_str()))
        return _handleNativeException(work)


    @staticmethod
    def calculate_total_size_required(directory_in: str) -> Optional[int]:
        cdef SystemString system_string = _str_to_system_string(directory_in)
        size = c_DiscBuilderGCN.CalculateTotalSizeRequired(SystemStringView(system_string.c_str()))
        if size:
            return cython.operator.dereference(size)
        return None

def open_disc_from_image(path: str) -> Optional[Tuple[DiscBase, bool]]:
    def work():
        disc = DiscBase()
        cdef c_bool is_wii = True

        cdef SystemString system_string = _str_to_system_string(path)
        with _log_exception_handler():
            disc.c_disc = OpenDiscFromImage(SystemStringView(system_string.c_str()), is_wii)
            checkException()
            return disc, is_wii
    return _handleNativeException(work)
