#!/bin/bash

BTCPAYSERVER_DOCKER_TOOLS_DIR=$(pwd)

# Installing go if needed
if ! hash go 2>/dev/null; then
    echo "Installing Go v1.13"
    apt-add-repository ppa:longsleep/golang-backports
    apt install golang-1.13-go
    ln -s /usr/lib/go-1.13/bin/go /usr/bin/go
    grep -qxF 'export GOPATH=/root/go' /root/.bashrc || echo 'export GOPATH=/root/go' >> /root/.bashrc
    grep -qxF 'export PATH=$PATH:$GOPATH/bin' /root/.bashrc || echo 'export PATH=$PATH:$GOPATH/bin' >> /root/.bashrc
fi

# Installing chantools if needed
if ! hash chantools 2>/dev/null; then
    echo "Installing chantools"
    cd $HOME
    git clone https://github.com/guggero/chantools.git
    cd chantools
    git checkout v0.5.0
    make install
fi

# Configuring python virtualenv
cd $BTCPAYSERVER_DOCKER_TOOLS_DIR/python
if ! test -f venv/bin/python 2>/dev/null; then
    echo "Installing python3 and python3 virtual env"
    apt install -y python3-pip
    apt install -y python3-venv
    python3 -m pip install --upgrade pip
    python3 -m venv ./venv
    ./venv/bin/pip install -r requirements.txt
fi

./venv/bin/python get_internal_lnd_derivation_scheme.py

# Remove the chantools log directory
rm -rf results
