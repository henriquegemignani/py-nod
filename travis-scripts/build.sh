#!/bin/bash

set -e

if [ -n "$PYTHON_VERSION" ]; then
    echo "Adding $PYTHON_VERSION to path"
    export PATH="/opt/python/${PYTHON_VERSION}/bin:$PATH"
    python -m pip install git+https://github.com/wtolson/auditwheel@manylinux2010
fi

python -m pip install Cython
python setup.py bdist_wheel

if [ -n "$PYTHON_VERSION" ]; then
    auditwheel repair dist/*.whl
fi