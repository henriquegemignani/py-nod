import nod
import hashlib
import py


def fprogress_callback(progress: float, name: str, bytes: int):
    pass


def sha256_checksum(filename, block_size=65536):
    sha256 = hashlib.sha256()
    with filename.open('rb') as f:
        for block in iter(lambda: f.read(block_size), b''):
            sha256.update(block)
    return sha256.hexdigest()


def test_packunpack(tmpdir):
    filesystem_root = py.path.local(__file__).new(basename="sample_game")
    image_out = tmpdir.join("game.iso")
    disc_builder = nod.DiscBuilderGCN(str(image_out), fprogress_callback)
    try:
        disc_builder.build_from_directory(str(filesystem_root))
        iso_hash = sha256_checksum(image_out)
        assert iso_hash == 'e51999888278dfab559c413ca3ec1ac3aa80a22e00633e74a86a0b7de3d0b033'

    finally:
        if image_out.exists():
            image_out.remove()