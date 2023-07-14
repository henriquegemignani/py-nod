import dataclasses


@dataclasses.dataclass()
class DolHeader:
    game_id: bytes
    disc_num: int
    disc_version: int
    audio_streaming: int
    stream_buf_sz: int
    wii_magic: int
    gcn_magic: int
    game_title: bytes
    disable_hash_verification: int
    disable_disc_enc: int
    debug_mon_off: int
    debug_load_addr: int
    dol_off: int
    fst_off: int
    fst_sz: int
    fst_max_sz: int
    fst_memory_address: int
    user_position: int
    user_sz: int
