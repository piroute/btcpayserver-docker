#!/bin/bash

# Inspired to
# https://gist.github.com/alexbosworth/2c5e185aedbdac45a03655b709e255a3
# https://stadicus.github.io/RaspiBolt/raspibolt_73_static_backup_dropox.html

if ! hash inotifywait 2>/dev/null; then
    apt install -y inotify-tools
fi

if [ -z "$NBITCOIN_NETWORK" ]
then
      echo "NBITCOIN_NETWORK not defined, exiting ..."
      exit 1
else
      echo "Using NBITCOIN_NETWORK = $NBITCOIN_NETWORK ..."
fi

# Define and create the backup folder
BACKUPS_FOLDER="/home/backups"
mkdir -p $BACKUPS_FOLDER

LND_CHANNEL_BACKUP_SOURCE="/var/lib/docker/volumes/generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/$NBITCOIN_NETWORK/channel.backup"
LND_CHANNEL_BACKUP_TARGET="$BACKUPS_FOLDER/channel.backup"

echo "LND_CHANNEL_BACKUP_SOURCE = $LND_CHANNEL_BACKUP_SOURCE"
echo "LND_CHANNEL_BACKUP_TARGET = $LND_CHANNEL_BACKUP_TARGET"

while true; do
    echo "Checking if LND_CHANNEL_BACKUP_SOURCE exists."
    if [ -f "$LND_CHANNEL_BACKUP_SOURCE" ]; then
        echo "LND_CHANNEL_BACKUP_TARGET exists. Performing a copy ..."
        cp $LND_CHANNEL_BACKUP_SOURCE $LND_CHANNEL_BACKUP_TARGET
        chmod 644 $LND_CHANNEL_BACKUP_TARGET
        
        echo "Copy performed. Watching $LND_CHANNEL_BACKUP_SOURCE ..."
        inotifywait $LND_CHANNEL_BACKUP_SOURCE
    else 
        echo "LND_CHANNEL_BACKUP_SOURCE does not exist. Going to sleep ..."
        sleep 10m
    fi
done
