#!/bin/bash

if [ `whoami` != 'root' ]; then
    echo "You must be root to run this script"
    read -n1 -p "Press any key to exit..."
    exit
fi

echo "Starting filesystem check!"

SWAP_CONFIG_FILE="/etc/dphys-swapfile"
SWAP_FILE_PATH=$( cat /etc/dphys-swapfile | grep ^CONF_SWAPFILE | awk '{print $1}' | sed -r 's/^CONF_SWAPFILE=([\/a-zA-Z0-9]*)$/\1/' )
echo "Swapfile is at $SWAP_FILE_PATH"

DOCKER_MOUNTPOINT="/var/lib/docker"
DOCKER_UUID=$( cat /etc/fstab | grep $DOCKER_MOUNTPOINT | awk '{print $1}' | sed -r 's/^UUID=([0-9a-fA-F-]{36})$/\1/' )
echo "Docker volumes are mounted at $DOCKER_MOUNTPOINT, the drive has UUID $DOCKER_UUID"

# HOME_MOUNTPOINT="/home"
# HOME_UUID=$( cat /etc/fstab | grep $HOME_MOUNTPOINT | awk '{print $1}' | sed -r 's/^UUID=([0-9a-fA-F-]{36})$/\1/' )
# echo "Home is mounted at $HOME_MOUNTPOINT, the drive has UUID $HOME_UUID"

echo "Turning off swap..."
dphys-swapfile swapoff

echo "Removing swap file..."
rm $SWAP_FILE_PATH

echo "Stopping btcpayserver..."
service btcpayserver stop

echo "Stopping docker..."
service docker stop

echo "Unmounting $DOCKER_MOUNTPOINT..."
umount $DOCKER_MOUNTPOINT

echo "Checking filesystem at /dev/disk/by-uuid/$DOCKER_UUID..."
fsck -f /dev/disk/by-uuid/$DOCKER_UUID

echo "Mounting $DOCKER_MOUNTPOINT..."
mount $DOCKER_MOUNTPOINT

echo "Starting docker..."
service docker start

echo "Starting btcpayserver..."
service btcpayserver start

echo "Setting up swap..."
dphys-swapfile setup

echo "Turning swap on..."
dphys-swapfile swapon

read -n1 -p "All done! Press any key to exit..."
exit
