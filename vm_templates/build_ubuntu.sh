#!/bin/env bash
bash _get_creds.sh
packer init ubuntu/ubuntu-2004.pkr.hcl
packer build -var-file="creds.json" ubuntu/ubuntu-2004.pkr.hcl