from setuptools import setup
from setuptools.extension import Extension
from Cython.Distutils import build_ext

ext_modules = [
    Extension(
        "dalib",
        ["test.pyx", "mahlib.cpp"],
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
    ext_modules=ext_modules,
)
