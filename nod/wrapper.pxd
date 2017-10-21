from libc.stddef cimport wchar_t
from libcpp cimport bool
from libcpp.string cimport string
from libcpp.memory cimport unique_ptr


cdef extern from "string" namespace "std":
    cdef cppclass wstring:
        # wrap-ignore
        wchar_t* c_str()


cdef extern from "nod/Util.hpp" namespace "nod":
    ctypedef wchar_t SystemChar

    cdef cppclass SystemUTF8View:
        SystemUTF8View(wstring)
        string utf8_str()

    cdef cppclass SystemStringView:
        SystemStringView(string)
        wstring sys_str()

cdef extern from "nod/nod.hpp" namespace "nod":
    cdef cppclass DiscBase:
        pass

    cdef struct ExtractionContext:
        bool force

    unique_ptr[DiscBase] OpenDiscFromImage(const SystemChar* path, bool& isWii)


cdef class DiscBaseWrapper:
    cdef unique_ptr[DiscBase] c_disc
