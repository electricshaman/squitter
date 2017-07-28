#!/bin/sh

# Helper file that can be sourced to export common env needed for testing and deploying.

# This file shouldn't be commited to your repo.
# If it shows up in your git status, run the following:
# git update-index --assume-unchanged env.sh

export MIX_TARGET=rpi3
export SQUITTER_NETWORK_SSID="White Government Van"
export SQUITTER_NETWORK_PSK="nothingtoseehere"
export SQUITTER_NETWORK_KEY_MGMT="WPA-PSK"
