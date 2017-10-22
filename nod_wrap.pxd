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
        SystemUTF8View(SystemString)
        string utf8_str()

    cdef cppclass SystemStringView:
        SystemStringView(string)
        SystemString sys_str()


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


cdef extern from "py-nod/nod_wrap_util.hpp" namespace "nod_wrap":
    function[void(const string&, float)] createProgressCallbackFunction(object, void (*)(object, string, float))
    function[void(float, const SystemString&, size_t)] createFProgressFunction(object, void (*)(object, float, const SystemString&, size_t));
