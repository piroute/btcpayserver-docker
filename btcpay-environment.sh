#!/bin/bash

#
# Setting constant environment environment
#

export BTCPAYGEN_LIGHTNING="lnd"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAY_ENABLE_SSH=true
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-more-memory;opt-add-electrs;$BTCPAYGEN_CUSTOM_FRAGMENTS"

# ELECTRS_NETWORK=bitcoin means mainnet. The value must be either 'bitcoin', 'testnet' or 'regtest'.
if [ $NBITCOIN_NETWORK == "mainnet" ]; then
    export ELECTRS_NETWORK="bitcoin"
else
    export ELECTRS_NETWORK=$NBITCOIN_NETWORK
fi

#
# End setting environment
#
