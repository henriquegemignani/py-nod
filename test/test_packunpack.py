import hashlib
import os
from pathlib import Path

import pytest

import nod


def fprogress_callback(progress: float, name: str, bytes: int):
    pass


def sha256_checksum(filename, block_size=65536):
    sha256 = hashlib.sha256()
    with filename.open('rb') as f:
        for block in iter(lambda: f.read(block_size), b''):
            sha256.update(block)
    return sha256.hexdigest()


@pytest.fixture(name="pack_sample_game")
def _pack_sample_game(tmp_path):
    filesystem_root = Path(__file__).parent.joinpath("sample_game")
    image_out = tmp_path.joinpath("game.iso")
    disc_builder = nod.DiscBuilderGCN(os.fspath(image_out), fprogress_callback)
    disc_builder.build_from_directory(os.fspath(filesystem_root))
    return image_out



def test_packunpack(pack_sample_game):
    iso_hash = sha256_checksum(pack_sample_game)
    assert iso_hash == '53a936817bb3fd6032b9496a7b5a55627e9d52dbf257cb2fcb927ff2c66ea950'


def test_build_and_check(pack_sample_game):
    result = nod.open_disc_from_image(os.fspath(pack_sample_game))
    assert result is not None
    assert not result[1]
    disc = pack_sample_game[0]

    assert disc.get_data_partition().files() == [
        "a.txt",
        "b.txt",
        "d/nested.txt",
    ]
    assert disc.get_data_partition().read_file("d/nested.txt").read(3) == b"abc"