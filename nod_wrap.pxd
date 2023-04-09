from typing import Tuple, Optional

from cpython.bytes cimport PyBytes_FromStringAndSize
from libc.stddef cimport wchar_t
from libc.stdint cimport uint8_t, uint32_t, int64_t, uint64_t
from libcpp cimport bool as c_bool
from libcpp.string cimport string
from libcpp.memory cimport unique_ptr
from libcpp.functional cimport function


cdef extern from "string" namespace "std":
    cdef cppclass string_view:
        string_view()
        const char* data()
        size_t size() const 
        # wrap-ignore

    cdef cppclass optional[T]:
        c_bool operator bool()
        T& operator*()
        void operator=(T)
        T& value()


cdef extern from "nod/IDiscIO.hpp" namespace "nod":
    cppclass IReadStream:
        uint64_t read(void* buf, uint64_t length) nogil
        void seek(int64_t offset, int whence) nogil
        uint64_t position() nogil const

    cppclass IPartReadStream(IReadStream):
        pass


cdef extern from "nod/DiscBase.hpp" namespace "nod":
    cdef cppclass EBuildResult:
        c_bool operator==(const EBuildResult&)

    cdef EBuildResult EBuildResult_Success "nod::EBuildResult::Success"
    cdef EBuildResult EBuildResult_Failed "nod::EBuildResult::Failed"
    cdef EBuildResult EBuildResult_DiskFull "nod::EBuildResult::DiskFull"
    
    cdef cppclass Kind:
        c_bool operator==(const Kind&)
        
    cdef Kind Kind_File "nod::Node::Kind::File"
    cdef Kind Kind_Directory "nod::Node::Kind::Directory"

    ctypedef function[void(float, string_view, size_t)] FProgress
    
    cppclass Node:

        cppclass DirectoryIterator:
            Node& operator*()
            c_bool operator==(const DirectoryIterator& other) const
            c_bool operator!=(const DirectoryIterator& other) const
            DirectoryIterator& operator++()

        unique_ptr[IPartReadStream] beginReadStream(uint64_t offset) const
        Kind getKind() const
        string_view getName() const
        uint64_t size() const
        DirectoryIterator find(string name) const
        DirectoryIterator begin()
        DirectoryIterator end()

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
        c_bool extractToDirectory(string path, const ExtractionContext& ctx) nogil except * const
        uint64_t getDOLSize() const
        const Header& getHeader() const
        const Node& getFSTRoot() const

    cdef cppclass DiscBase:
        IPartition* getDataPartition()
        IPartition* getUpdatePartition()


cdef extern  from "nod/DiscGCN.hpp" namespace "nod":
    cdef cppclass DiscBuilderGCN:
        DiscBuilderGCN(string outPath, FProgress progressCB)
        EBuildResult buildFromDirectory(string dirIn) nogil except *

        @staticmethod
        optional[uint64_t] CalculateTotalSizeRequired(string dirIn) nogil


cdef extern from "nod/nod.hpp" namespace "nod":
    cdef struct ExtractionContext:
        c_bool force
        function[void(string_view, float)] progressCB

    unique_ptr[DiscBase] OpenDiscFromImage(string path, c_bool& isWii) nogil


cdef extern from "py-nod/nod_wrap_util.hpp" namespace "nod_wrap":
    function[void(string_view, float)] createProgressCallbackFunction(object, void (*)(object, const string&, float) except *)
    function[void(float, string_view, size_t)] createFProgressFunction(object, void (*)(object, float, const string&, size_t) except *)

    object getDol(const IPartition*)
    void doPrint(const IPartition*)
    object _handleNativeException(object)
    void checkException() except *
