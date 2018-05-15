#!/bin/bash

set -o allexport
source environment
set +o allexport

run_list=$1

# Are we on a vanilla system?
if ! command -v chef >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get -y install curl
    curl https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chefdk -c stable -v $CHEFDK_V
fi &&

chef generate cookbook cookbooks/elixir_web
sudo -E chef-client --local-mode --runlist ${run_list:='recipe[elixir_web::default]'}
