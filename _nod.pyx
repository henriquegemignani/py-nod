from enum import Enum
from typing import Tuple, Optional, Callable

from libcpp cimport bool as c_bool
from libcpp.string cimport string
from libcpp.memory cimport unique_ptr

from nod_wrap cimport ExtractionContext as c_ExtractionContext, \
    createProgressCallbackFunction, DiscBase as c_DiscBase, \
    string_view, \
    OpenDiscFromImage, SystemStringView, SystemUTF8Conv, SystemString, SystemStringConv, \
    DiscBuilderGCN as c_DiscBuilderGCN, createFProgressFunction, EBuildResult,\
    EBuildResult_Success, EBuildResult_Failed, EBuildResult_DiskFull, string_to_system_string

cdef SystemString _str_to_system_string(str path):
    return string_to_system_string(path.encode("utf-8"))
    #cdef string the_string = path.encode("utf-8")
    #cdef string_view the_view = string_view(the_string.c_str())
    #return SystemString(SystemStringConv(the_view).sys_str())

# TODO: Returning a StringView like this seems like a bad idea: a pointer to already free'd memory
#cdef SystemStringView _str_to_system_string(str path):
#    return SystemStringConv(string_view(path.encode("utf-8"))).sys_str()


ProgressCallback = Callable[[float, str, int], None]

cdef void invoke_callback_function(object callback, const string& a, float progress):
    callback(a.decode("utf-8"), progress)

cdef void invoke_fprogress_function(object callback, float totalProg, const string& fileName, size_t fileBytesXfered):
    callback(totalProg, fileName.decode("utf-8"), fileBytesXfered)

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

    def extract_to_directory(self, path: str, context: ExtractionContext) -> bool:
        cdef SystemString system_string = _str_to_system_string(path)
        return self.c_partition.extractToDirectory(
            SystemStringView(system_string.c_str()),
            context.c_context
        )

cdef class DiscBase:
    cdef unique_ptr[c_DiscBase] c_disc

    def get_data_partition(self) -> Optional[Partition]:
        cdef c_DiscBase.IPartition*partition = self.c_disc.get().getDataPartition()
        if partition:
            return Partition.create(partition)
        else:
            return None

class BuildResult(Enum):
    Success = 1
    Failed = 2
    DiskFull = 3


cdef object convert_e_build_result(EBuildResult result):
    if result == EBuildResult_Success:
        return BuildResult.Success
    elif result == EBuildResult_Failed:
        return BuildResult.Failed
    elif result == EBuildResult_DiskFull:
        return BuildResult.DiskFull
    else:
        raise ValueError("Unknown EBuildResult")

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

    def build_from_directory(self, directory_in: str) -> BuildResult:
        cdef SystemString system_string = _str_to_system_string(directory_in)
        return convert_e_build_result(self.c_builder.buildFromDirectory(SystemStringView(system_string.c_str())))

    @staticmethod
    def calculate_total_size_required(directory_in: str) -> int:
        cdef SystemString system_string = _str_to_system_string(directory_in)
        return c_DiscBuilderGCN.CalculateTotalSizeRequired(SystemStringView(system_string.c_str()))

def open_disc_from_image(path: str) -> Optional[Tuple[DiscBase, bool]]:
    disc = DiscBase()
    cdef c_bool is_wii = True

    cdef SystemString system_string = _str_to_system_string(path)
    disc.c_disc = OpenDiscFromImage(SystemStringView(system_string.c_str()), is_wii)

    if disc.c_disc:
        return disc, is_wii
    else:
        return None
