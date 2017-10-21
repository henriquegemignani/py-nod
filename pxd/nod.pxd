cdef extern from "nod/nod.hpp":
    cdef struct ExtractionContext:
        bool force

    void OpenDiscFromImage()
