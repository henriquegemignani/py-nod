import os
import platform
from pathlib import Path

import setuptools_cmake_helper
from setuptools import setup

file_dir = Path(__file__).parent.absolute().relative_to(Path().absolute())
extra_compile_args = []
cmake_project_dir = file_dir.joinpath("external", "nod")

custom_include_paths = [
    cmake_project_dir.joinpath("include"),
    cmake_project_dir.joinpath("logvisor", "include"),
    cmake_project_dir.joinpath("logvisor", "fmt", "include"),
]

extra_compile_args = []

if platform.system() == "Windows":
    extra_compile_args.append("-DUNICODE")
    extra_compile_args.append("/std:c++latest")
    extra_compile_args.append("/MD")
    extra_compile_args.append("/Zc:__cplusplus")
else:
    extra_compile_args.append("-std=c++2a")

ext_modules = [
    setuptools_cmake_helper.CMakeExtension(
        "_nod",
        [
            os.fspath(file_dir.joinpath("_nod.pyx")),
            os.fspath(file_dir.joinpath("py-nod/nod_wrap_util.cxx")),
        ],
        cmake_project=cmake_project_dir,
        cmake_targets=[
            "nod",
            "logvisor",
            "fmt",
        ],
        language="c++",
        extra_compile_args=extra_compile_args,
        extra_objects=[],
    )
]

cythonized_ext_modules = setuptools_cmake_helper.cythonize_extensions(
    ext_modules,
    include_paths=[os.fspath(p) for p in custom_include_paths],
    language_level="3",
)

setup(
    cmdclass={
        "build_ext": setuptools_cmake_helper.CMakeBuild,
    },
    ext_modules=cythonized_ext_modules,
)
