#!/bin/bash

# Install the Splitgraph library and the layered querying foreign data wrapper.
# We could use the Postgres entrypoint system instead but it's run as the non-root user
# and this container isn't for the sgr tool anyway.

cd /splitgraph

ln -s /usr/bin/pip3 /usr/bin/pip

# Dirty but we use python 3 system-wide
mv /usr/bin/python /usr/bin/python2
ln -s /usr/bin/python3 /usr/bin/python

curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py | python
# Install globally (otherwise we'll need to find a way to get Multicorn to see the venv)
source $HOME/.poetry/env
poetry config settings.virtualenvs.create false
poetry install --no-dev