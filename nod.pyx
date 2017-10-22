from typing import Tuple, Optional

from libcpp cimport bool as c_bool
from libcpp.string cimport string
from libcpp.memory cimport unique_ptr

from nod_wrap cimport ExtractionContext as c_ExtractionContext, createProgressCallbackFunction, DiscBase as c_DiscBase, OpenDiscFromImage, SystemStringView, wstring

cdef void invoke_callback_function(object callback, const string& a, float progress):
    callback(a.decode("utf-8"), progress)

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

    def extract_to_directory(self, path: str, context: ExtractionContext):
        self.c_partition.extractToDirectory(
            _str_to_system_string(path),
            context.c_context
        )

cdef class DiscBase:
    cdef unique_ptr[c_DiscBase] c_disc

    def get_data_partition(self):
        cdef c_DiscBase.IPartition*partition = self.c_disc.get().getDataPartition()
        if partition:
            wrapper = Partition()
            wrapper.c_partition = partition
            return wrapper
        else:
            return None

def open_disc_from_image(path: str) -> Optional[Tuple[DiscBase, bool]]:
    disc = DiscBase()
    cdef c_bool is_wii = True
    disc.c_disc = OpenDiscFromImage(_str_to_system_string(path).c_str(), is_wii)

    if disc.c_disc:
        return disc, is_wii
    else:
        return None

cdef wstring _str_to_system_string(str path):
    return SystemStringView(path.encode("utf-8")).sys_str()
