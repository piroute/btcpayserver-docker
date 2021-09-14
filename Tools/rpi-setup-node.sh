#!/bin/bash

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root."
    echo "Use the command 'sudo su -' (include the trailing hypen) and try again"
    exit 1
fi

echo -e "GET http://google.com HTTP/1.0\n\n" | nc google.com 80 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "The node must be online to run this script"
    echo "Please connect to an internet connection and try again"
    exit 1
fi

cd /root/BTCPayNode/btcpayserver-docker

git fetch origin
REPO_CURRENT_BRANCH=$(git symbolic-ref -q HEAD)
REPO_CURRENT_BRANCH=${REPO_CURRENT_BRANCH##refs/heads/}
REPO_CURRENT_BRANCH=${REPO_CURRENT_BRANCH:-HEAD}
REPO_NEW_COMMITS=$(git rev-list HEAD...origin/$REPO_CURRENT_BRANCH --count)
if [[ $REPO_NEW_COMMITS -ne 0 ]]; then
  git pull
  echo "Wow, good news, we pulled $REPO_NEW_COMMITS updates from the remote repo."
  read -n1 -p "This program will now exit. Please press any key to exit, then restart the setup..."
  exit
fi

# Read configuration from user
DEFAULT_NBITCOIN_NETWORK=mainnet
DEFAULT_LIGHTNING_ALIAS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 15 | head -n 1)
DEFAULT_BTCPAY_HOST=btcpay.local

NODE_CONFIG_OK=false
while ! $NODE_CONFIG_OK; do
  echo ""
  echo " -------------------- "
  echo "| Node configuration |"
  echo " -------------------- "
  echo ""

  while true; do
    read -p "Bitcoin network, mainnet/testnet (default $DEFAULT_NBITCOIN_NETWORK): " NBITCOIN_NETWORK
    NBITCOIN_NETWORK=${NBITCOIN_NETWORK:-$DEFAULT_NBITCOIN_NETWORK}
    case $NBITCOIN_NETWORK in
        mainnet|testnet ) break;;
        * ) ;;
    esac
  done
  
  while true; do
    read -p "Your public nick on the lightning network, (default $DEFAULT_LIGHTNING_ALIAS): " LIGHTNING_ALIAS
    LIGHTNING_ALIAS=${LIGHTNING_ALIAS:-$DEFAULT_LIGHTNING_ALIAS}
    case $LIGHTNING_ALIAS in
        * ) break;;
    esac
  done
  
  while true; do
    read -p "Your node hostname, (default $DEFAULT_BTCPAY_HOST): " BTCPAY_HOST
    BTCPAY_HOST=${BTCPAY_HOST:-$DEFAULT_BTCPAY_HOST}
    case $BTCPAY_HOST in
        *.local ) break;;
        * ) ;;
    esac
  done

  echo ""
  echo "----------------- "
  echo "Bitcoin Network = $NBITCOIN_NETWORK"
  echo "Lightning alias = $LIGHTNING_ALIAS"
  echo "Node hostname   = $BTCPAY_HOST"
  echo "----------------- "
  echo ""

  while true; do
    read -p "Does the configuration look okay? Yes/No: " yn
    case $yn in
        Yes|yes|Y|y ) NODE_CONFIG_OK=true; break;;
        No|no|N|n ) NODE_CONFIG_OK=false; break;;
        * ) ;;
    esac
  done
done

export NBITCOIN_NETWORK
export LIGHTNING_ALIAS
export BTCPAY_HOST

. helpers.sh
ansible_install

cd /root/BTCPayNode/btcpayserver-docker/Ansible
ansible-playbook -i hosts playbook_localhost_setup.yml

#
# Btcpay configuration
#

echo "#!/bin/bash

cd /root/BTCPayNode/btcpayserver-docker
source /root/BTCPayNode/node_configuration_script.sh
. ./btcpay-setup.sh -i
" > /root/BTCPayNode/configure.sh
chmod +x /root/BTCPayNode/configure.sh

# Start configuration
cd /root/BTCPayNode
. ./configure.sh

#
# Exit
#

read -n1 -p "Node setup completed, press any key to exit..."
exit
