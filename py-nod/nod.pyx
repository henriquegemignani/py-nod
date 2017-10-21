from typing import Tuple, Optional

from libc.stddef cimport wchar_t
from libcpp cimport bool as c_bool
from libcpp.string cimport string
from libcpp.memory cimport unique_ptr


cdef extern from "string" namespace "std":
    cdef cppclass wstring:
        # wrap-ignore
        wchar_t* c_str()


cdef extern from "nod/Util.hpp" namespace "nod":
    ctypedef wchar_t SystemChar
    ctypedef wstring SystemString

    cdef cppclass SystemUTF8View:
        SystemUTF8View(wstring)
        string utf8_str()

    cdef cppclass SystemStringView:
        SystemStringView(string)
        wstring sys_str()


cdef extern from "nod/DiscBase.hpp" namespace "nod":
    cdef cppclass DiscBase:
        cppclass IPartition:
            void extractToDirectory(const SystemString& path, const ExtractionContext& ctx)

        IPartition* getDataPartition()
        IPartition* getUpdatePartition()


cdef extern from "nod/nod.hpp" namespace "nod":
    cdef struct ExtractionContext:
        c_bool force

    unique_ptr[DiscBase] OpenDiscFromImage(const SystemChar* path, c_bool& isWii)


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
