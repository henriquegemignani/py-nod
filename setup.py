import os
import platform
import re
import subprocess
import sys
from distutils.version import LooseVersion

from Cython.Build import cythonize
from Cython.Build.Dependencies import default_create_extension
from setuptools import setup
from setuptools.command.build_ext import build_ext
from setuptools.extension import Extension

is_windows = platform.system() == "Windows"

file_dir = os.path.dirname(__file__)


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

        if is_windows:
            cmake_version = LooseVersion(re.search(r'version\s*([\d.]+)', out.stdout).group(1))
            if cmake_version < '3.1.0':
                raise RuntimeError("CMake >= 3.1.0 is required on Windows")

        super().run()

    def build_extension(self, ext):
        cmake_options = ext.cmake_options
        extdir = os.path.abspath(os.path.dirname(self.get_ext_fullpath(ext.name)))
        cmake_args = ['-DCMAKE_ARCHIVE_OUTPUT_DIRECTORY=' + extdir,
                      '-DPYTHON_EXECUTABLE=' + sys.executable,
                      '-DCMAKE_POSITION_INDEPENDENT_CODE=YES']
        library_output_dir = extdir
        
        cfg = 'Debug' if self.debug else 'Release'
        build_args = ['--config', cfg]
        
        if is_windows:
            cmake_args += ['-DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_{}={}'.format(cfg.upper(), extdir)]
            if sys.maxsize > 2 ** 32:
                cmake_args += ['-A', 'x64']
            build_args += ['--', '/m', '/verbosity:minimal']
            library_name_format = "{}.lib"
        else:
            cmake_args += ['-DCMAKE_BUILD_TYPE=' + cfg]
            build_args += ['--', '-j2']
            library_name_format = "lib{}.a"
        
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
        if self.force:
            subprocess.run(
                ['cmake', '--build', '.', '--target', 'clean'] + build_args,
                cwd=self.build_temp,
                check=True
            )
        
        for target, target_output in cmake_options["targets"].items():
            subprocess.run(
                ['cmake', '--build', '.', '--target', target] + build_args,
                cwd=self.build_temp,
                check=True
            )
            ext.extra_objects.append(
                os.path.join(library_output_dir, library_name_format.format(target))
            )

        super().build_extension(ext)


nod_submodule = os.path.join(os.path.dirname(__file__), "external", "nod")

custom_include_paths = [
    os.path.join(nod_submodule, "include"),
    os.path.join(nod_submodule, "logvisor", "include"),
    os.path.join(nod_submodule, "logvisor", "fmt", "include"),
]

extra_compile_args = []

if is_windows:
    extra_compile_args.append("-DUNICODE")
    extra_compile_args.append("/std:c++17")
    extra_compile_args.append("/MD")
else:
    extra_compile_args.append("-std=c++17")

ext_modules = [
    CMakeExtension(
        "_nod",
        [
            os.path.join(file_dir, "_nod.pyx"),
            os.path.join(file_dir, "py-nod/nod_wrap_util.cxx")
        ],
        cmake_options={
            "dir": nod_submodule,
            "targets": {
                "nod": "lib",
                "logvisor": "logvisor",
                "fmt": "fmt",
            },
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
    compiler_directives={
        'embedsignature': True,
        'language_level': '3',
    },
    create_extension=create_extension,
)

for ext_module in cythonized_ext_modules:
    ext_module.include_dirs = custom_include_paths

with open(os.path.join(file_dir, "README.md")) as readme_file:
    long_description = readme_file.read()

setup(
    name='nod',
    use_scm_version=True,
    author='Henrique Gemignani',
    url='https://github.com/henriquegemignani/py-nod',
    description='Python bindings for the nod library.',
    long_description=long_description,
    long_description_content_type='text/markdown',
    packages=["nod"],
    scripts=[
    ],
    package_data={
    },
    license='License :: OSI Approved :: MIT License',
    classifiers=[
        'Development Status :: 4 - Beta',
        'Programming Language :: Python :: 3 :: Only',
        'License :: OSI Approved :: MIT License',
    ],
    install_requires=[],
    setup_requires=[
        'Cython>=0.27.0',
        'setuptools>=38.6.0',
        'wheel>=0.31.0',
    ],
    cmdclass={
        'build_ext': CMakeBuild,
    },
    ext_modules=cythonized_ext_modules,
)
