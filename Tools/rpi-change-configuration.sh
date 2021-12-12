#!/bin/bash

BTCPAY_CONFIG_FILE=/root/BTCPayNode/node_configuration_script.sh

OLD_STATS=`stat -c %Y "$BTCPAY_CONFIG_FILE"`

# echo $OLD_STATS

nano "$BTCPAY_CONFIG_FILE"

NEW_STATS=`stat -c %Y "$BTCPAY_CONFIG_FILE"`

# echo $NEW_STATS

if [[ $NEW_STATS -gt $OLD_STATS ]] ; then  
  while true; do
    read -p "Configuration modified, apply the new configuration now? Yes/No [No]: " yn
    case $yn in
        Yes|yes|Y|y ) /root/BTCPayNode/configure.sh; break;;
        * ) break;;
    esac
  done
else
  echo "Configuration has not been modified."
fi

read -n1 -p "Press any key to exit..."
exit
