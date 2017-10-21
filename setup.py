import os
from setuptools import setup
from setuptools.extension import Extension
from Cython.Distutils import build_ext
from Cython.Build import cythonize

ext_modules = [
    Extension(
        "dalib",
        ["nod/nod.pyx"],
        language='c++',
        # extra_objects=["nod.lib"],
    )
]
setup(
    name='nod',
    version="0.0.0",
    author='Henrique Gemignani',
    url='https://github.com/henriquegemignani/py-nod',
    description='Python bindings for the nod library.',
    # packages=find_packages(),
    scripts=[
    ],
    package_data={
        # "randovania": ["data/*"]
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
    ext_modules=cythonize(
        ext_modules,
        include_path=[
            os.path.join(os.path.dirname(__file__), "nod", "include"),
        ],
    ),
)
