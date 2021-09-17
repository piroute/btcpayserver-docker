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
    echo "Install chantools from https://github.com/guggero/chantools.git"
    read -n1 -p "Press any key to exit..."
    exit 1
fi

BTCPAYSERVER_DOCKER_TOOLS_DIR="$(dirname "$BTCPAY_ENV_FILE")/btcpayserver-docker/Tools"
if ! test -f $BTCPAYSERVER_DOCKER_TOOLS_DIR/python/venv/bin/python 2>/dev/null; then
    echo "Install a python3 virtual env in $BTCPAYSERVER_DOCKER_TOOLS_DIR/python/venv"
    read -n1 -p "Press any key to exit..."
    exit 1
fi

if ! hash jq 2>/dev/null; then
    echo "Install jq"
    read -n1 -p "Press any key to exit..."
    exit 1
fi

# Make sure we run lnd
if [ $BTCPAYGEN_LIGHTNING != 'lnd' ]; then
    echo "This script only works with lnd internal lightning node"
    read -n1 -p "Press any key to exit..."
    exit 1
fi

# Make sure we have the seed
WALLET_UNLOCK_PATH="/var/lib/docker/volumes/generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/$NBITCOIN_NETWORK/walletunlock.json"
echo "Reading wallet seed from $WALLET_UNLOCK_PATH"
if ! test -f $WALLET_UNLOCK_PATH 2>/dev/null; then
    echo "walletunlock.json file does not exist at $WALLET_UNLOCK_PATH. Make sure the node is synchronised"
    read -n1 -p "Press any key to exit..."
    exit 1
fi

# Read the seed
export AEZEED_MNEMONIC=$(jq -r '.cipher_seed_mnemonic | join(" ")' $WALLET_UNLOCK_PATH)

# We didn't set a passphrase for this example seed, we need to indicate this by
# passing in a single dash character.
export AEZEED_PASSPHRASE="-"

CHANTOOLS_OUTPUT=$(chantools showrootkey)
# echo $CHANTOOLS_OUTPUT

BIP32_ROOT_KEY=$(echo $CHANTOOLS_OUTPUT | sed -nE 's/^.*Your BIP32 HD root key is: ([A-Za-z0-9]+).*/\1/p')
# echo $BIP32_ROOT_KEY

$BTCPAYSERVER_DOCKER_TOOLS_DIR/python/venv/bin/python $BTCPAYSERVER_DOCKER_TOOLS_DIR/python/get_internal_lnd_derivation_scheme.py $BIP32_ROOT_KEY

# Remove the chantools log directory
rm -rf results

printf "\n"

read -n1 -p "Press any key to exit..."
exit 0
