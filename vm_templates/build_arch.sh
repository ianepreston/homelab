#!/bin/env bash
bash _get_creds.sh
packer init arch/arch.pkr.hcl
packer build -var-file="creds.json" arch/arch.pkr.hcl