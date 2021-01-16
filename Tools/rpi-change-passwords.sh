#!/bin/bash

while true; do
    read -p "Do you want to change the pi user password? Yes/No [No]: " yn
    case $yn in
        Yes ) 
        passwd pi
        read -n1 -p "All done! Press any key to exit..."
        exit
        ;;
        * ) 
        break
        ;;
    esac
done

SDA1_CRYPT_UUID=$( cat /etc/crypttab | grep sda1_crypt | awk '{print $2}' | sed -r 's/^UUID=([0-9a-fA-F-]{36})$/\1/' )
# echo "sda1_crypt has UUID $SDA1_CRYPT_UUID"

if [ -z "$SDA1_CRYPT_UUID" ]
then
    echo "INFO: You cannot change ssd encryption password because ssd is not encrypted!"
else
    while true; do
        read -p "Do you want to change the ssd encryption password? Yes/No [No]: " yn
        case $yn in
            Yes ) 
            cryptsetup luksChangeKey /dev/disk/by-uuid/$SDA1_CRYPT_UUID
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
