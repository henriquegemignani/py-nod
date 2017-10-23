import os
import platform
import re
import subprocess
from distutils.version import LooseVersion

import sys

from Cython.Build.Dependencies import default_create_extension
from setuptools import setup
from setuptools.extension import Extension
from setuptools.command.build_ext import build_ext
from Cython.Build import cythonize


class CMakeExtension(Extension):
    def __init__(self, name, sources, cmake_options, *args, **kw):
        super().__init__(name, sources, *args, **kw)
        cmake_options["dir"] = os.path.abspath(cmake_options["dir"])
        self.cmake_options = cmake_options


class CMakeBuild(build_ext):
    def run(self):
        try:
            out = subprocess.run(['cmake', '--version'],
                                 stdout=subprocess.PIPE, check=True,
                                 universal_newlines=True)
        except (FileNotFoundError, subprocess.CalledProcessError):
            raise RuntimeError("CMake must be installed to build the following extensions: " +
                               ", ".join(e.name for e in self.extensions))

        if platform.system() == "Windows":
            cmake_version = LooseVersion(re.search(r'version\s*([\d.]+)', out.stdout).group(1))
            if cmake_version < '3.1.0':
                raise RuntimeError("CMake >= 3.1.0 is required on Windows")

        super().run()

    def build_extension(self, ext):
        cmake_options = ext.cmake_options
        extdir = os.path.abspath(os.path.dirname(self.get_ext_fullpath(ext.name)))
        cmake_args = ['-DCMAKE_LIBRARY_OUTPUT_DIRECTORY=' + extdir,
                      '-DPYTHON_EXECUTABLE=' + sys.executable]

        cfg = 'Debug' if self.debug else 'Release'
        build_args = ['--config', cfg]
        if self.force:
            build_args.append("--clean-first")

        if platform.system() == "Windows":
            cmake_args += ['-DCMAKE_LIBRARY_OUTPUT_DIRECTORY_{}={}'.format(cfg.upper(), extdir)]
            if sys.maxsize > 2 ** 32:
                cmake_args += ['-A', 'x64']
            build_args += ['--', '/m', '/verbosity:minimal']
            extension = "lib"
        else:
            cmake_args += ['-DCMAKE_BUILD_TYPE=' + cfg]
            build_args += ['--', '-j2']
            extension = "a"

        env = os.environ.copy()
        env['CXXFLAGS'] = '{} -DVERSION_INFO=\\"{}\\"'.format(env.get('CXXFLAGS', ''),
                                                              self.distribution.get_version())
        if not os.path.exists(self.build_temp):
            os.makedirs(self.build_temp)

        subprocess.run(
            ['cmake', cmake_options["dir"]] + cmake_args,
            cwd=self.build_temp,
            env=env,
            check=True
        )
        subprocess.run(
            ['cmake', '--build', '.'] + build_args,
            cwd=self.build_temp,
            check=True
        )

        ext.extra_objects.extend(
            os.path.join(self.build_temp, lib.format(
                config=cfg,
                ext=extension
            ))
            for lib in cmake_options.get("libraries", [])
        )
        super().build_extension(ext)


is_windows = True

nod_submodule = os.path.join(os.path.dirname(__file__), "external", "nod")

custom_include_paths = [
    os.path.join(nod_submodule, "include"),
    os.path.join(nod_submodule, "logvisor", "include"),
]

extra_compile_args = []

if is_windows:
    extra_compile_args.append("-DUNICODE")

ext_modules = [
    CMakeExtension(
        "_nod",
        ["_nod.pyx", "py-nod/nod_wrap_util.cxx"],
        cmake_options={
            "dir": nod_submodule,
            "libraries": [
                "lib/{config}/nod.{ext}",
                "logvisor/{config}/logvisor.{ext}",
            ]
        },
        language='c++',
        extra_compile_args=extra_compile_args,
        extra_objects=[
        ],
    )
]


def create_extension(template, kwds):
    """"""
    kwds["cmake_options"] = template.cmake_options
    return default_create_extension(template, kwds)

cythonized_ext_modules = cythonize(
    ext_modules,
    include_path=custom_include_paths,
    create_extension=create_extension,
)

for ext_module in cythonized_ext_modules:
    ext_module.include_dirs = custom_include_paths

setup(
    name='nod',
    version="0.1.1",
    author='Henrique Gemignani',
    url='https://github.com/henriquegemignani/py-nod',
    description='Python bindings for the nod library.',
    packages=["nod"],
    scripts=[
    ],
    package_data={
    },
    classifiers=[
        'Development Status :: 4 - Beta',
        'Programming Language :: Python :: 3 :: Only',
    ],
    install_requires=[],
    setup_requires=[
        'Cython',
    ],
    cmdclass={
        'build_ext': CMakeBuild,
    },
    ext_modules=cythonized_ext_modules,
)
