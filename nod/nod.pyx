from typing import Tuple, Optional

from libcpp cimport bool as cBool
from libcpp.memory cimport unique_ptr
from wrapper cimport OpenDiscFromImage as _OpenDiscFromImage, SystemStringView, DiscBaseWrapper




def open_disc_from_image(path: str) -> Optional[Tuple[DiscBaseWrapper, bool]]:
    disc = DiscBaseWrapper()
    cdef cBool is_wii = True
    disc.c_disc = _OpenDiscFromImage(
        SystemStringView(path.encode("utf-8")).sys_str().c_str(), is_wii)

    if disc.c_disc:
        return disc, is_wii
    else:
        return None
