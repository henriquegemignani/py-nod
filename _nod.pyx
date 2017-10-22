from typing import Tuple, Optional, Callable

from libcpp cimport bool as c_bool
from libcpp.string cimport string
from libcpp.memory cimport unique_ptr

from nod_wrap cimport ExtractionContext as c_ExtractionContext, \
    createProgressCallbackFunction, DiscBase as c_DiscBase, \
    OpenDiscFromImage, SystemStringView, SystemUTF8View, SystemString, \
    DiscBuilderGCN as c_DiscBuilderGCN, createFProgressFunction, EBuildResult

cdef str _system_string_to_str(SystemString path):
    return SystemUTF8View(path).utf8_str().decode("utf-8")

cdef SystemString _str_to_system_string(str path):
    return SystemStringView(path.encode("utf-8")).sys_str()

ProgressCallback = Callable[[float, str, int], None]

cdef void invoke_callback_function(object callback, const string& a, float progress):
    callback(a.decode("utf-8"), progress)

cdef void invoke_fprogress_function(object callback, float totalProg, const SystemString& fileName, size_t fileBytesXfered):
    callback(totalProg, _system_string_to_str(fileName), fileBytesXfered)

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
        return self.c_partition.extractToDirectory(
            _str_to_system_string(path),
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

cdef class DiscBuilderGCN:
    cdef c_DiscBuilderGCN* c_builder

    def __init__(self, out_path: str, progress_callback: ProgressCallback):
        pass

    def __cinit__(self, out_path: str, progress_callback: ProgressCallback):
        self.c_builder = new c_DiscBuilderGCN(_str_to_system_string(out_path).c_str(),
                                              createFProgressFunction(progress_callback, invoke_fprogress_function))

    def __dealloc__(self):
        del self.c_builder

    def build_from_directory(self, directory_in: str) -> EBuildResult:
        return self.c_builder.buildFromDirectory(_str_to_system_string(directory_in).c_str())

    @staticmethod
    def calculate_total_size_required(directory_in: str) -> int:
        return c_DiscBuilderGCN.CalculateTotalSizeRequired(_str_to_system_string(directory_in).c_str())

def open_disc_from_image(path: str) -> Optional[Tuple[DiscBase, bool]]:
    disc = DiscBase()
    cdef c_bool is_wii = True
    disc.c_disc = OpenDiscFromImage(_str_to_system_string(path).c_str(), is_wii)

    if disc.c_disc:
        return disc, is_wii
    else:
        return None
