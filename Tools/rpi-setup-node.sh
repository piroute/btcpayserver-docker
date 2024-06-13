#!/bin/bash

preliminary_checks() {
  if [ "$(id -u)" != "0" ]; then
      echo "This script must be run as root."
      echo "Use the command 'sudo su -' (include the trailing hypen) and try again."
      read -n1 -p "Press any key to exit..." && exit 1
  fi

  echo -e "GET http://google.com HTTP/1.0\n\n" | nc google.com 80 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
      echo "The node must be online to run this script"
      echo "Please connect to an internet connection and try again."
      read -n1 -p "Press any key to exit..." && exit 1
  fi
}

check_github_updates() {
  echo ""
  echo " -------------------- "
  echo "|   Check updates    |"
  echo " -------------------- "
  echo ""

  # Taken from: https://stackoverflow.com/questions/3258243/check-if-pull-needed-in-git
  REPO_CURRENT_HASH=$(git rev-parse HEAD)
  REPO_ORIGIN_HASH=$(git ls-remote $(git rev-parse --abbrev-ref @{u} | sed 's/\// /g') | cut -f1)
  if [[ ! -z $REPO_ORIGIN_HASH &&  "$REPO_CURRENT_HASH" != "$REPO_ORIGIN_HASH" ]]; then
    git pull
    echo "Wow, good news, we pulled $REPO_NEW_COMMITS updates from the remote repo."
    read -n1 -p "This program will now exit. Please press any key to exit, then restart the setup..."
    exit
  else
    echo "Not pulling updates from the remote repo."
  fi
}

configure_as_new() {
  echo ""
  echo " -------------------- "
  echo "|      New node      |"
  echo " -------------------- "
  echo ""

  DEFAULT_NBITCOIN_NETWORK=mainnet
  DEFAULT_LIGHTNING_ALIAS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 15 | head -n 1)
  DEFAULT_BTCPAY_HOST=btcpay.local

  while true; do
    read -p "Bitcoin network, mainnet/testnet/signet (default $DEFAULT_NBITCOIN_NETWORK): " NBITCOIN_NETWORK
    NBITCOIN_NETWORK=${NBITCOIN_NETWORK:-$DEFAULT_NBITCOIN_NETWORK}
    case $NBITCOIN_NETWORK in
        mainnet|testnet|signet ) break;;
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

  export NBITCOIN_NETWORK
  export LIGHTNING_ALIAS
  export BTCPAY_HOST
}

restore_from_backup() {
  echo ""
  echo " -------------------- "
  echo "|    Restore node    |"
  echo " -------------------- "
  echo ""

  # Ensure microsd is mounted at BACKUP_FOLDER
  BACKUP_FOLDER="/opt/backups"
  MICROSD_PARTITION="/dev/mmcblk0p1"
  mkdir -p $BACKUP_FOLDER

  if ! grep -qs $BACKUP_FOLDER /proc/mounts; then
    if test -e $MICROSD_PARTITION 2>/dev/null; then
      mount -o defaults,uid=1000,gid=1000,noatime,nofail $MICROSD_PARTITION $BACKUP_FOLDER
    else
      read -n1 -p "Cannot find a microsd. Please insert microsd with backups. Press any key to exit..."
      exit 1
    fi
  fi

  BACKUP_ENCRYPTED_PATH=$(find $BACKUP_FOLDER -maxdepth 1 -type f -name "*backup.tar.gz.enc" | tail -n 1)
  if [ -z $BACKUP_ENCRYPTED_PATH ]; then
    echo "Cannot find a backup. Please insert microsd with backups."
    read -n1 -p "Press any key to exit..." && exit 1
  fi

  CONFIRM_BACKUP_TO_RESTORE=false
  while true; do
    read -p "Restore from latest backup \"$BACKUP_ENCRYPTED_PATH\"? Yes/No: " yn
    case $yn in
        Yes|yes|Y|y ) CONFIRM_BACKUP_TO_RESTORE=true; break;;
        No|no|N|n ) CONFIRM_BACKUP_TO_RESTORE=false; break;;
        * ) ;;
    esac
  done

  if ! $CONFIRM_BACKUP_TO_RESTORE; then
    echo "Please insert microsd with the backup you want to restore."
    read -n1 -p "Press any key to exit..." && exit 1
  fi

  BACKUP_TAR_PATH="/tmp/backup-to-restore.tar.gz"
  rm -rf $BACKUP_TAR_PATH
  read -p "Insert your lnd mnemonic to decrypt backup: " AEZEED_MNEMONIC
  echo "Decrypting the backup..."
  openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:"$AEZEED_MNEMONIC" -in $BACKUP_ENCRYPTED_PATH -out $BACKUP_TAR_PATH 2>/dev/null
  if [ $? -ne 0 ]
  then
    echo "ERROR: cannot decrypt backup with provided menmonic."
    read -n1 -p "Press any key to exit..." && exit 1
  fi

  BACKUP_PATH="/tmp/backup-to-restore"
  rm -rf $BACKUP_PATH && mkdir -p $BACKUP_PATH

  # Extract the node backup info
  BACKUP_INFO_PATH="root/BTCPayNode/node_backup_info"
  tar -C $BACKUP_PATH -zxf $BACKUP_TAR_PATH $BACKUP_INFO_PATH
  if [ $? -ne 0 ]
  then
    echo "ERROR: cannot extract of the node backup info."
    read -n1 -p "Press any key to exit..." && exit 1
  fi

  # Calculate the backup version
  NODE_BACKUP_INFO_VERSION=$(grep BACKUP_INFO_VERSION $BACKUP_PATH/$BACKUP_INFO_PATH | cut -d '=' -f2)
  BACKUP_VERSION=2
  case $NODE_BACKUP_INFO_VERSION in
    1 )
      GIT_BRANCH=$(grep GIT_BRANCH $BACKUP_PATH/$BACKUP_INFO_PATH | cut -d '=' -f2)
      case $GIT_BRANCH in
	      "prod" ) BACKUP_VERSION=1 ;;
        * ) ;;
      esac
      ;;
    * ) ;;
  esac

  echo "Backup decryption succesful, found backup version $BACKUP_VERSION. Extracting configuration..."

  # Depending on the backup version, obtain the position of config script path
  NODE_CONFIG_SCRIPT_PATH="root/BTCPayNode/node_configuration_script.sh"
  case $BACKUP_VERSION in
    1 ) NODE_CONFIG_SCRIPT_PATH="var/lib/docker/opt/node_configuration_script.sh" ;;
    * ) ;;
  esac

  # Extract the node configuration script
  tar -C $BACKUP_PATH -zxf $BACKUP_TAR_PATH $NODE_CONFIG_SCRIPT_PATH
  if [ $? -ne 0 ]
  then
    echo "ERROR: cannot extract of the node configuration."
    read -n1 -p "Press any key to exit..." && exit 1
  fi

  NBITCOIN_NETWORK=$(cat $BACKUP_PATH/$NODE_CONFIG_SCRIPT_PATH | grep -oP "NBITCOIN_NETWORK=\K(.*)$")
  LIGHTNING_ALIAS=$(cat $BACKUP_PATH/$NODE_CONFIG_SCRIPT_PATH | grep -oP "LIGHTNING_ALIAS=\K(.*)$")
  BTCPAY_HOST=$(cat $BACKUP_PATH/$NODE_CONFIG_SCRIPT_PATH | grep -oP "BTCPAY_HOST=\K(.*)$")

  export BACKUP_TAR_PATH
  export BACKUP_VERSION
  export NBITCOIN_NETWORK
  export LIGHTNING_ALIAS
  export BTCPAY_HOST
}

#
# Start
#

cd /root/BTCPayNode/btcpayserver-docker

# Preliminary checks on user and internet connection
preliminary_checks

# Check for uptates
check_github_updates

# Start the configuration
NODE_CONFIG_OK=false
CONFIGURE_AS_NEW=false
while ! $NODE_CONFIG_OK; do
  echo ""
  echo " -------------------- "
  echo "|     Node setup     |"
  echo " -------------------- "
  echo ""

  while true; do
    read -p "Configure the node as a new device or restore from backup? New/Backup: " yn
    case $yn in
        New|new|N|n ) CONFIGURE_AS_NEW=true; break;;
        Backup|backup|B|b ) CONFIGURE_AS_NEW=false; break;;
        * ) ;;
    esac
  done

  if $CONFIGURE_AS_NEW; then
    configure_as_new
  else
    restore_from_backup
  fi

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

echo ""
echo " -------------------- "
echo "|    Start config    |"
echo " -------------------- "
echo ""

. helpers.sh
ansible_install
if [ $? -ne 0 ]; then
  echo "ERROR: cannot install ansible, check that your internet connection is stable."
  read -n1 -p "Press any key to exit..." && exit 1
fi

#
# Btcpay configuration
#

echo ""
echo " -------------------- "
echo "|    Config btcpay   |"
echo " -------------------- "
echo ""

if $CONFIGURE_AS_NEW; then
  # If we configure as new we create the configuration script
  echo "export NBITCOIN_NETWORK=$NBITCOIN_NETWORK
  export LIGHTNING_ALIAS=$LIGHTNING_ALIAS
  export BTCPAY_HOST=$BTCPAY_HOST
  " > /root/BTCPayNode/node_configuration_script.sh
else
  # If we use a backup then we use the existing configuration script
  echo "Restoring backup ..."
  tar -xpzf $BACKUP_TAR_PATH -C / --numeric-owner --keep-newer-files --warning=no-ignore-newer

  case $BACKUP_VERSION in
    1 )
    # Perform migration from v1 backup to current version
    mv /var/lib/docker/opt/node_configuration_script.sh /root/BTCPayNode/node_configuration_script.sh
    rm -rf /opt/mkcert
    rm -rf /home/pi/rootCA.pem
    ;;
    2 )
    # Perform migration from v2 backup to current version
    ;;
    * )
    ;;
  esac

  echo "... Backup restored, starting with btcpay configuration!"
fi

echo "#!/bin/bash

cd /root/BTCPayNode/btcpayserver-docker
source /root/BTCPayNode/node_configuration_script.sh
. ./btcpay-setup.sh -i
" > /root/BTCPayNode/configure.sh
chmod +x /root/BTCPayNode/configure.sh

# Start configuration
cd /root/BTCPayNode
. ./configure.sh
if [ $? -ne 0 ]; then
  echo "ERROR: BTCPayNode configure failed."
  read -n1 -p "Press any key to exit..." && exit 1
fi

#
# Exit
#

echo ""
echo " -------------------- "
echo "|   Setup complete!  |"
echo " -------------------- "
echo ""
read -n1 -p "Press any key to exit..." && exit
