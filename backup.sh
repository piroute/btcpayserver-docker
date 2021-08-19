#!/bin/bash

# Execute with
# BACKUP_PROVIDER=Localfs LOCALFS_TARGET=/opt/backups BACKUP_TIMESTAMP=true ./backup.sh
# (currently not supported) BACKUP_PROVIDER=Dropbox DROPBOX_TOKEN=sl... BACKUP_TIMESTAMP=true ./backup.sh
# tar -zxvf backup.tar.gz

# This script might look like a good idea. Please be aware of these important issues:
#
# - The backup file is not encrypted and it contains your lightning private keys.
#   Consider encrypting before uploading or using another backup tool like duplicity.
# - Old channel state is toxic and you can loose all your funds, if you or someone
#   else closes a channel based on the backup with old state - and the state changes
#   often! If you publish an old state (say from yesterday's backup) on chain, you
#   WILL LOSE ALL YOUR FUNDS IN A CHANNEL, because the counterparty will publish a
#   revocation key!

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root."
    echo "Use the command 'sudo su -' (include the trailing hypen) and try again"
    read -n1 -p "Press any key to exit..."
    exit 1
fi

if [ -z "$BTCPAY_BASE_DIRECTORY" ] || [ -z "$NBITCOIN_NETWORK" ]; then
    source $HOME/.profile
    source /etc/profile.d/btcpay-env.sh
fi

case "$BACKUP_PROVIDER" in
  "Dropbox")
    if [ -z "$DROPBOX_TOKEN" ]; then
        echo "Set DROPBOX_TOKEN environment variable and try again."
        read -n1 -p "Press any key to exit..."
        exit 1
    fi
    echo "Dropbox backup provider still not supported."
    read -n1 -p "Press any key to exit..."
    exit 1
    ;;

  "SCP")
    if [ -z "$SCP_TARGET" ]; then
        echo "Set SCP_TARGET environment variable and try again."
        read -n1 -p "Press any key to exit..."
        exit 1
    fi
    ;;

  "Localfs")
    if [ -z "$LOCALFS_TARGET" ]; then
        echo "Set LOCALFS_TARGET environment variable and try again."
        read -n1 -p "Press any key to exit..."
        exit 1
    fi
    ;;

  *)
    echo "No BACKUP_PROVIDER set. Backing up to local directory."
    ;;
esac

# preparation
docker_dir=/var/lib/docker
volumes_dir="$docker_dir/volumes"
backup_dir="$docker_dir/opt/backups"
pihome_dir="/home/pi"
mkcert_dir="/opt/mkcert"

# Ensure backup dir exists
mkdir -p $backup_dir

filename="backup.tar.gz"
filename_encrypted="backup.tar.gz.enc"
dumpname="postgres.sql"

if [ "$BACKUP_TIMESTAMP" == true ]; then
  timestamp=$(date "+%Y%m%d-%H%M%S")
  filename="$timestamp-$filename"
  filename_encrypted="$timestamp-$filename_encrypted"
  dumpname="$timestamp-$dumpname"
fi

backup_path="$backup_dir/${filename}"
backup_path_encrypted="$backup_dir/${filename_encrypted}"
dbdump_path="$backup_dir/${dumpname}"
node_config_path="$BTCPAY_BASE_DIRECTORY/node_configuration_script.sh"

cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
. helpers.sh

# dump database
echo "Dumping database …"
btcpay_dump_db $dumpname

if [[ "$1" == "--only-db" ]]; then
    tar -cvzf $backup_path $dbdump_path
else
    # stop docker containers, save files and restart
    echo "Stopping BTCPay Server …"
    btcpay_down

    echo "Backing up files …"
    tar \
      --exclude="$volumes_dir/generated_bitcoin_datadir/*" \
      --exclude="$volumes_dir/generated_litecoin_datadir/*" \
      --exclude="$volumes_dir/generated_electrs_datadir/*" \
      --exclude="$volumes_dir/**/logs/*" \
      --exclude="$pihome_dir/.cache/*" \
      --exclude="$pihome_dir/.local/share/Trash/*" \
      --exclude="$pihome_dir/.pcsc10/*" \
      --exclude="$pihome_dir/thinclient_drives" \
      -czf $backup_path \
      $dbdump_path $pihome_dir $node_config_path $mkcert_dir $volumes_dir

    echo "Restarting BTCPay Server …"
    btcpay_up
fi

# encrypt backup with lnd mnemonic if possible
WALLET_UNLOCK_PATH="/var/lib/docker/volumes/generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/$NBITCOIN_NETWORK/walletunlock.json"
echo "Reading wallet seed from $WALLET_UNLOCK_PATH"

if ! hash jq 2>/dev/null; then
    echo "Cannot encrypt backup, install jq"
elif [ $BTCPAYGEN_LIGHTNING != 'lnd' ]; then
    echo "Cannot encrypt backup, it only works with lnd internal lightning node"
elif ! test -f $WALLET_UNLOCK_PATH 2>/dev/null; then
    echo "Cannot encrypt backup, walletunlock.json file does not exist at $WALLET_UNLOCK_PATH. Make sure the node is synchronised"
else
    # Read the seed
    AEZEED_MNEMONIC=$(jq -r '.cipher_seed_mnemonic | join(" ")' $WALLET_UNLOCK_PATH)
    
    # Encrypt the backup
    echo "Encrypt backup with lnd internal lightning node seed"
    openssl enc -in $backup_path \
      -aes-256-cbc \
      -pbkdf2 -pass pass:"$AEZEED_MNEMONIC" \
      > $backup_path_encrypted

    # Decrypt with
    # openssl enc -d -aes-256-cbc -pbkdf2 -pass env:AEZEED_MNEMONIC -in $backup_path_encrypted -out $backup_path
fi

# post processing
# use backup provider only if encryption has been succesful
if test -f $backup_path_encrypted 2>/dev/null; then
  # Copy encrypted backup
  case $BACKUP_PROVIDER in
    "Dropbox")
      echo "Uploading to Dropbox …"
      docker volume create dropbox_backup_datadir
      cp $backup_path_encrypted $volumes_dir/dropbox_backup_datadir/_data
      # docker run --name backup --env DROPBOX_TOKEN=$DROPBOX_TOKEN -v dropbox_backup_datadir:/data jvandrew/btcpay-dropbox:1.0.5 $filename_encrypted
      echo "Deleting local backup …"
      rm $backup_path_encrypted
      rm $volumes_dir/dropbox_backup_datadir/_data/$filename_encrypted
      ;;

    "SCP")
      echo "Uploading via SCP …"
      scp $backup_path_encrypted $SCP_TARGET
      echo "Deleting local backup …"
      rm $backup_path_encrypted
      ;;

    "Localfs")
      echo "Copying to local file system …"
      cp $backup_path_encrypted $LOCALFS_TARGET
      rm $backup_path_encrypted
      ;;

    *)
      echo "Backed up to $backup_path_encrypted"
      ;;
  esac
  
  # and cleanup
  rm $dbdump_path
  rm $backup_path

else
  echo "Unencrypted backup at $backup_path"
  
  # cleanup
  rm $dbdump_path
fi

read -n1 -p "Backup done. Press any key to exit..."
exit
