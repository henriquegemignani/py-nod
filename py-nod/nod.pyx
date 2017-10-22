from typing import Tuple, Optional

from libc.stddef cimport wchar_t
from libc.stdint cimport uint64_t
from libcpp cimport bool as c_bool
from libcpp.string cimport string
from libcpp.memory cimport unique_ptr
from libcpp.functional cimport function


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
    cdef enum EBuildResult:
        Success
        Failed
        DiskFull

    ctypedef function[void(float, const SystemString&, size_t)] FProgress

    cdef cppclass DiscBase:
        cppclass IPartition:
            void extractToDirectory(const SystemString& path, const ExtractionContext& ctx)

        IPartition* getDataPartition()
        IPartition* getUpdatePartition()


cdef extern  from "nod/DiscGCN.hpp" namespace "nod":
    cdef cppclass DiscBuilderGCN:
        DiscBuilderGCN(const SystemChar* outPath, FProgress progressCB)
        EBuildResult buildFromDirectory(const SystemChar* dirIn)

    uint64_t "DiscBuilderGCN::CalculateTotalSizeRequired"(const SystemChar* dirIn)


cdef extern from "nod/nod.hpp" namespace "nod":
    cdef struct ExtractionContext:
        c_bool force
        function[void(const string&, float)] progressCB

    unique_ptr[DiscBase] OpenDiscFromImage(const SystemChar* path, c_bool& isWii)


cdef extern from "nod_wrap_util.hpp" namespace "nod_wrap":
    function[void(const string&, float)] createProgressCallbackFunction(object, void (*)(object, string, float))


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
