#!/bin/env bash
ansible-galaxy collection install -r ./collections/requirements.yml

# Should be able to remove this once devcontainer is updated
# sudo apt update
# sudo apt install python3-pip
# pip3 install websocket-client