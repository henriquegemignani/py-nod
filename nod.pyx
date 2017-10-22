from typing import Tuple, Optional

from libc.stddef cimport wchar_t
from libc.stdint cimport uint64_t
from libcpp cimport bool as c_bool
from libcpp.string cimport string
from libcpp.memory cimport unique_ptr
from libcpp.functional cimport function

from nod_wrap cimport *

cdef void invoke_callback_function(object callback, const string& a, float progress):
    callback(a.decode("utf-8"), progress)


cdef class ExtractionContextWrapper:
    cdef ExtractionContext c_context

    def __cinit__(self):
        self.c_context = ExtractionContext()

    @property
    def force(self):
        return self.c_context.force

    @force.setter
    def force(self, value):
        self.c_context.force = value

    def set_progress_callback(self, callback):
        self.c_context.progressCB = createProgressCallbackFunction(callback, invoke_callback_function)


cdef class PartitionWrapper:
    cdef DiscBase.IPartition* c_partition

    def extract_to_directory(self, path: str, context: ExtractionContextWrapper):
        self.c_partition.extractToDirectory(
            _str_to_system_string(path),
            context.c_context
        )


cdef class DiscBaseWrapper:
    cdef unique_ptr[DiscBase] c_disc

    def get_data_partition(self):
        cdef DiscBase.IPartition* partition = self.c_disc.get().getDataPartition()
        if partition:
            wrapper = PartitionWrapper()
            wrapper.c_partition = partition
            return wrapper
        else:
            return None


def open_disc_from_image(path: str) -> Optional[Tuple[DiscBaseWrapper, bool]]:
    disc = DiscBaseWrapper()
    cdef c_bool is_wii = True
    disc.c_disc = OpenDiscFromImage(_str_to_system_string(path).c_str(), is_wii)

    if disc.c_disc:
        return disc, is_wii
    else:
        return None


cdef wstring _str_to_system_string(str path):
    return SystemStringView(path.encode("utf-8")).sys_str()
