#!/bin/bash

cd /root/BTCPayNode/btcpayserver-docker
./btcpay-update.sh

read -n1 -p "Node updated, press any key to exit..."
exit
