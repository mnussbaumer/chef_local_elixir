#!/bin/bash

# Usage: ./deploy_kitchen.sh [host]

host="$1"
recipes="$2"
echo $recipes
# The host key might change when we instantiate a new VM, so
# we remove (-R) the old host key from known_hosts
ssh-keygen -R "${host#*@}" 2> /dev/null

tar cj . | ssh -o 'StrictHostKeyChecking no' "$host" "
sudo rm -rf ~/chef &&
mkdir ~/chef &&
cd ~/chef &&
tar xj &&
sudo bash install.sh $recipes"
