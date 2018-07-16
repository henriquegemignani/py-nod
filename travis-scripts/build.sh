#!/bin/bash

set -e

V=$(cat .python-version)
PYTHON_VERSION="cp${V}-cp${V}m/"
/opt/python/${PYTHON_VERSION}/bin/python -m pip install Cython
/opt/python/${PYTHON_VERSION}/bin/python setup.py bdist_wheel
