#!/bin/bash

set -e

: "${BTCPAYGEN_DOCKER_IMAGE:=btcpayserver/docker-compose-generator}"
if [ "$BTCPAYGEN_DOCKER_IMAGE" == "btcpayserver/docker-compose-generator:local" ]
then
    docker build docker-compose-generator -f docker-compose-generator/linuxamd64.Dockerfile --tag $BTCPAYGEN_DOCKER_IMAGE
else
    set +e
    docker pull $BTCPAYGEN_DOCKER_IMAGE
    docker rmi $(docker images btcpayserver/docker-compose-generator --format "{{.Tag}};{{.ID}}" | grep "^<none>" | cut -f2 -d ';') > /dev/null 2>&1
    set -e
fi

# This script will run docker-compose-generator in a container to generate the yml files
docker run -v "$(pwd)/Generated:/app/Generated" \
           -v "$(pwd)/docker-compose-generator/docker-fragments:/app/docker-fragments" \
           -v "$(pwd)/docker-compose-generator/crypto-definitions.json:/app/crypto-definitions.json" \
           -e "BTCPAYGEN_CRYPTO1=$BTCPAYGEN_CRYPTO1" \
           -e "BTCPAYGEN_CRYPTO2=$BTCPAYGEN_CRYPTO2" \
           -e "BTCPAYGEN_CRYPTO3=$BTCPAYGEN_CRYPTO3" \
           -e "BTCPAYGEN_CRYPTO4=$BTCPAYGEN_CRYPTO4" \
           -e "BTCPAYGEN_CRYPTO5=$BTCPAYGEN_CRYPTO5" \
           -e "BTCPAYGEN_CRYPTO6=$BTCPAYGEN_CRYPTO6" \
           -e "BTCPAYGEN_CRYPTO7=$BTCPAYGEN_CRYPTO7" \
           -e "BTCPAYGEN_CRYPTO8=$BTCPAYGEN_CRYPTO8" \
           -e "BTCPAYGEN_CRYPTO9=$BTCPAYGEN_CRYPTO9" \
           -e "BTCPAYGEN_REVERSEPROXY=$BTCPAYGEN_REVERSEPROXY" \
           -e "BTCPAYGEN_ADDITIONAL_FRAGMENTS=$BTCPAYGEN_ADDITIONAL_FRAGMENTS" \
           -e "BTCPAYGEN_EXCLUDE_FRAGMENTS=$BTCPAYGEN_EXCLUDE_FRAGMENTS" \
           -e "BTCPAYGEN_LIGHTNING=$BTCPAYGEN_LIGHTNING" \
           -e "BTCPAYGEN_SUBNAME=$BTCPAYGEN_SUBNAME" \
           -e "BTCPAY_HOST_SSHAUTHORIZEDKEYS=$BTCPAY_HOST_SSHAUTHORIZEDKEYS" \
           -e "EPS_XPUB=$EPS_XPUB" \
           -e "ELECTRS_NETWORK=$ELECTRS_NETWORK" \
           --rm $BTCPAYGEN_DOCKER_IMAGE

if [ "$BTCPAYGEN_REVERSEPROXY" == "nginx" ]; then
    cp Production/nginx.tmpl Generated/nginx.tmpl
fi

[[ -f "Generated/pull-images.sh" ]] && chmod +x Generated/pull-images.sh
[[ -f "Generated/save-images.sh" ]] && chmod +x Generated/save-images.sh

#
# opt-add-guacamole
#

if [[ -f Generated/guacamole/user-mapping.xml && $(find "Generated/guacamole/user-mapping.xml" -mtime +30 -print) ]]; then
  # Force recreate of guacamole authentication keys if older than 30 days
  echo "Guacamole configuration file exists and is older than 30 days, forcing recreation..."
  rm Generated/guacamole/user-mapping.xml
else
  echo "Guacamole configuration file either does not exist or is newer than 30 days, do nothing..."
fi

if [[ $BTCPAYGEN_ADDITIONAL_FRAGMENTS = *opt-add-guacamole* ]]; then
  echo "Guacamole configuration started"

  if [[ ! -f Generated/guacamole/user-mapping.xml ]]; then
    echo "Guacamole recreate configuration files with a new password"
    mkdir -p Generated/guacamole
    cp Production/guacamole/user-mapping.xml Generated/guacamole/user-mapping.xml
    
    # Setup a random guacamole password
    GUACAMOLE_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    sed -i 's/password="PASSWORD"/password="'$GUACAMOLE_PASSWORD'"/' Generated/guacamole/user-mapping.xml
    sed -i 's/username=USERNAME&password=PASSWORD/username=USERNAME\&password='$GUACAMOLE_PASSWORD'/' Generated/docker-compose.generated.yml
    
    # Always stop guacamole container upon configuration file change, otherwise changes are not read
    docker stop --time 1 generated_guacamole_1 || true
  else
    echo "Guacamole use already existing password"
    GUACAMOLE_PASSWORD=$(grep -Po 'password=\"\K.+(?=\">)' Generated/guacamole/user-mapping.xml)
    sed -i 's/username=USERNAME&password=PASSWORD/username=USERNAME\&password='$GUACAMOLE_PASSWORD'/' Generated/docker-compose.generated.yml
  fi
fi
