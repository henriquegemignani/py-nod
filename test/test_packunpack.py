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


@pytest.fixture(name="pack_sample_game", scope="session")
def _pack_sample_game(tmp_path_factory):
    filesystem_root = Path(__file__).parent.joinpath("sample_game")
    image_out = tmp_path_factory.mktemp("iso").joinpath("game.iso")
    disc_builder = nod.DiscBuilderGCN(image_out, fprogress_callback)
    disc_builder.build_from_directory(filesystem_root)
    return image_out



def test_packunpack(pack_sample_game):
    iso_hash = sha256_checksum(pack_sample_game)
    assert iso_hash == '0d98f9bf2c94051bec6145373c0b2c4baee0b35ccb066eaf354fd5a7b9324816'


def test_build_and_check(pack_sample_game):
    result = nod.open_disc_from_image(pack_sample_game)
    assert result is not None
    assert not result[1]
    disc = result[0]

    files = disc.get_data_partition().files()
    assert sorted(files) == [
        "a.txt",
        "b.txt",
        "d/nested.txt",
    ]
    assert disc.get_data_partition().read_file("d/nested.txt").read(3) == b"abc"

    f = disc.get_data_partition().read_file("b.txt")
    f.seek(2, 1)
    assert f.read(1) == b"3"
    f.seek(1)
    assert f.read(2) == b"23"

    f.close()
    with pytest.raises(RuntimeError):
        f.read(1)
