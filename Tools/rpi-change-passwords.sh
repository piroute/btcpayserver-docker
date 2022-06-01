#!/bin/bash

while true; do
    read -p "Do you want to change the pi user password? Yes/No [No]: " yn
    case $yn in
        Yes|yes|Y|y ) 
        passwd pi
        read -n1 -p "All done! Press any key to exit..."
        exit
        ;;
        * ) 
        break
        ;;
    esac
done

ROOT_LINE_NUMBER=$( df -h | awk '{print $6}' | grep -n -E ^/$ | cut -d : -f 1 )
ROOT_CRYPT_TARGET=$( df -h | sed $ROOT_LINE_NUMBER'q;d' | awk '{print $1}' | sed -r 's/^\/dev\/mapper\/(.+)$/\1/' )
ROOT_CRYPT_SOURCE=$( cat /etc/crypttab | grep $ROOT_CRYPT_TARGET | awk '{print $2}' )

if echo $ROOT_CRYPT_SOURCE | grep -q "^UUID="; then
#   echo "ROOT_CRYPT_SOURCE is specified with UUID..."
  ROOT_CRYPT_DEVICE=/dev/disk/by-uuid/$(echo $ROOT_CRYPT_SOURCE | sed -r 's/^UUID=([0-9a-fA-F-]{36})$/\1/' )
else
#   echo "ROOT_CRYPT_SOURCE is specified as a device, leaving as it is..."
  ROOT_CRYPT_DEVICE=$ROOT_CRYPT_SOURCE
fi

if [ -z "$ROOT_CRYPT_DEVICE" ]
then
    echo "INFO: You cannot change ssd encryption password because ssd is not encrypted!"
else
    while true; do
        read -p "Do you want to change the ssd ($ROOT_CRYPT_DEVICE) encryption password? Yes/No [No]: " yn
        case $yn in
            Yes|yes|Y|y ) 
            cryptsetup luksChangeKey $ROOT_CRYPT_DEVICE
            read -n1 -p "All done! Press any key to exit..."
            exit
            ;;
            * ) 
            break
            ;;
        esac
    done
fi

read -n1 -p "All done! Press any key to exit..."
exit
