from typing import Tuple, Optional

from libc.stddef cimport wchar_t
from libc.stdint cimport uint8_t, uint32_t, uint64_t
from libcpp cimport bool as c_bool
from libcpp.string cimport string
from libcpp.memory cimport unique_ptr
from libcpp.functional cimport function


cdef extern from "string" namespace "std":
    cdef cppclass string_view:
        string_view()
        string_view(char*)
        # wrap-ignore

    cdef cppclass wstring:
        # wrap-ignore
        wstring()
        wstring(wchar_t*)
        wstring(wstring_view)
        wchar_t* c_str()

    cdef cppclass wstring_view:
        wstring_view()
        wstring_view(wchar_t*)
        # wrap-ignore

    cdef cppclass optional[T]:
        c_bool operator bool()
        T& operator*()


cdef extern from "nod/Util.hpp" namespace "nod":
    ctypedef wchar_t SystemChar
    ctypedef wstring SystemString
    ctypedef wstring_view SystemStringView

    cdef cppclass SystemUTF8Conv:
        SystemUTF8Conv(SystemStringView)
        char* utf8_str()
        # lying to Cython here, since otherwise it believes we can't create a std::string from a string_view

    cdef cppclass SystemStringConv:
        SystemStringConv(string_view)
        SystemStringView sys_str()


cdef extern from "nod/DiscBase.hpp" namespace "nod":
    cdef cppclass EBuildResult:
        c_bool operator==(const EBuildResult&)

    cdef EBuildResult EBuildResult_Success "nod::EBuildResult::Success"
    cdef EBuildResult EBuildResult_Failed "nod::EBuildResult::Failed"
    cdef EBuildResult EBuildResult_DiskFull "nod::EBuildResult::DiskFull"

    ctypedef function[void(float, SystemStringView, size_t)] FProgress

    cppclass Header:
        char m_gameID[6]
        char m_discNum
        char m_discVersion
        char m_audioStreaming
        char m_streamBufSz
        char m_unk1[14]
        uint32_t m_wiiMagic
        uint32_t m_gcnMagic
        char m_gameTitle[64]
        char m_disableHashVerification
        char m_disableDiscEnc
        char m_unk2[0x39e]
        uint32_t m_debugMonOff
        uint32_t m_debugLoadAddr
        char m_unk3[0x18]
        uint32_t m_dolOff
        uint32_t m_fstOff
        uint32_t m_fstSz
        uint32_t m_fstMaxSz
        uint32_t m_fstMemoryAddress
        uint32_t m_userPosition
        uint32_t m_userSz
        uint8_t padding1[4]

    cppclass IPartition:
        c_bool extractToDirectory(SystemStringView path, const ExtractionContext& ctx) except * const
        uint64_t getDOLSize() const
        const Header& getHeader() const

    cdef cppclass DiscBase:
        IPartition* getDataPartition()
        IPartition* getUpdatePartition()


cdef extern  from "nod/DiscGCN.hpp" namespace "nod":
    cdef cppclass DiscBuilderGCN:
        DiscBuilderGCN(SystemStringView outPath, FProgress progressCB)
        EBuildResult buildFromDirectory(SystemStringView dirIn) except *

        @staticmethod
        optional[uint64_t] CalculateTotalSizeRequired(SystemStringView dirIn)


cdef extern from "nod/nod.hpp" namespace "nod":
    cdef struct ExtractionContext:
        c_bool force
        function[void(string_view, float)] progressCB

    unique_ptr[DiscBase] OpenDiscFromImage(SystemStringView path, c_bool& isWii)


cdef extern from "py-nod/nod_wrap_util.hpp" namespace "nod_wrap":
    function[void(string_view, float)] createProgressCallbackFunction(object, void (*)(object, const string&, float) except *)
    function[void(float, SystemStringView, size_t)] createFProgressFunction(object, void (*)(object, float, const string&, size_t) except *)
    SystemString string_to_system_string(const string&)

    object getDol(const IPartition*)
    void registerLogvisorToExceptionConverter()
    void removeLogvisorToExceptionConverter()
    object _handleNativeException(object)
    void checkException() except *
