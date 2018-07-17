#!/bin/bash

set -e

if [ -n "$PYTHON_VERSION" ]; then
    echo "Adding $PYTHON_VERSION to path"
    export PATH="/opt/python/${PYTHON_VERSION}/bin:$PATH"
fi

python -m pip install Cython
python setup.py bdist_wheel
