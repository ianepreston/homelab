#!/bin/env bash
bash _requirements.sh
bash _get_creds.sh
eval $(cat creds.sh)
ansible-playbook -i inventory.xen_orchestra.yml d-mars.yml