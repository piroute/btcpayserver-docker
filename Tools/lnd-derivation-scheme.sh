#!/bin/bash

if [ `whoami` != 'root' ]; then
    echo "You must be root to run this script"
    read -n1 -p "Press any key to exit..."
    exit 1
fi

cd /tmp
# echo "Working in directory $(pwd)"

source /etc/profile.d/btcpay-env.sh
source $HOME/.profile

if [[ -z "$BTCPAYGEN_LIGHTNING" ||  -z "$NBITCOIN_NETWORK" ]]; then
    echo "Must define BTCPAYGEN_LIGHTNING and NBITCOIN_NETWORK"
    read -n1 -p "Press any key to exit..."
    exit 1
fi

if ! hash go 2>/dev/null; then
    echo "Install Go v1.13"
    read -n1 -p "Press any key to exit..."
    exit 1
fi

if ! hash chantools 2>/dev/null; then
    echo "Install chantools v0.5.0 from https://github.com/guggero/chantools.git"
    read -n1 -p "Press any key to exit..."
    exit 1
fi

BTCPAYSERVER_DOCKER_TOOLS_DIR="$(dirname "$BTCPAY_ENV_FILE")/btcpayserver-docker/Tools"
if ! test -f $BTCPAYSERVER_DOCKER_TOOLS_DIR/python/venv/bin/python 2>/dev/null; then
    echo "Install a python3 virtual env in $BTCPAYSERVER_DOCKER_TOOLS_DIR/python/venv"
    read -n1 -p "Press any key to exit..."
    exit 1
fi

$BTCPAYSERVER_DOCKER_TOOLS_DIR/python/venv/bin/python $BTCPAYSERVER_DOCKER_TOOLS_DIR/python/get_internal_lnd_derivation_scheme.py

# Remove the chantools log directory
rm -rf results

printf "\n"

read -n1 -p "Press any key to exit..."
exit 0
