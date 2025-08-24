#!/usr/bin/env bash
bash _requirements.sh
bash _get_creds.sh
eval $(cat creds.sh)
ansible-playbook -i inventory.yml ares.yml
