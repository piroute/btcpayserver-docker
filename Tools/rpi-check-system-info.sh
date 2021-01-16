#!/bin/bash

echo "---------- Network Info ---------"

IP_ETHERNET=$( ip address show eth0 | grep -E -o "inet ([0-9]{1,3}[\.]){3}[0-9]{1,3}" | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" );
if [ -z "$IP_ETHERNET" ]
then
      echo "Ethernet is not connected"
else
      echo "Ethernet is connected, IP = $IP_ETHERNET"
fi

IP_WIFI=$( ip address show wlan0 | grep -E -o "inet ([0-9]{1,3}[\.]){3}[0-9]{1,3}" | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" );
if [ -z "$IP_WIFI" ]
then
      echo "Wi-Fi is not connected"
else
      echo "Wi-Fi is connectedm IP = $IP_WIFI"
fi

echo "---------- Thermal Info ---------"

TEMP_CPU=$( vcgencmd measure_temp | awk -F"[=C']" '{print $2}' )
echo "Temperature of the CPU is $TEMP_CPU C"

if ! hash smartctl 2>/dev/null 
then
    echo "Install smartmontools 7.1 to get SSD temperature"
else
  TEMP_SSD=$( smartctl -d sntjmicron -x /dev/sda1 | grep Temperature: | awk '{print $2 ".0"}' )
  echo "Temperature of the SSD is $TEMP_SSD C"
fi

read -n1 -p "Press any key to exit..."
exit
