#!/bin/env bash
bash _requirements.sh
bash _get_creds.sh
eval $(cat creds.sh)
ansible-playbook -i physical-inventory.yml rover2.yml