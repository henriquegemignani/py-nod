import os
from setuptools import setup
from setuptools.extension import Extension
from Cython.Distutils import build_ext
from Cython.Build import cythonize

custom_include_paths = [
    os.path.join(os.path.dirname(__file__), "py-nod", "include"),
]

ext_modules = [
    Extension(
        "_nod",
        ["_nod.pyx", "py-nod/nod_wrap_util.cxx"],
        language='c++',
        # extra_link_args=["-debug"],
        # extra_compile_args=["-DUNICODE", "-Zi", "/Od"],
        extra_compile_args=["-DUNICODE"],
        extra_objects=[
            "py-nod/nod.lib",
            "py-nod/logvisor.lib",
        ],
    )
]
cythonized_ext_modules = cythonize(
    ext_modules,
    include_path=custom_include_paths,
)

for ext_module in cythonized_ext_modules:
    ext_module.include_dirs = custom_include_paths


setup(
    name='nod',
    version="0.1.0",
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
        'build_ext': build_ext,
    },
    ext_modules=cythonized_ext_modules,
)
