#!/bin/env bash
if [ ! -f creds.sh ]; then
	echo "Credentials file doesn't already exist, loading from Bitwarden."
	echo "Logging into bitwarden"
	bw login
	echo "Getting the xen orchestra creds"
	touch creds.sh
	USER=ipreston
	PASS=$(bw get password xo.ipreston.net)
	echo "export ANSIBLE_XO_HOST='xo.ipreston.net'" >> creds.sh
	echo "export ANSIBLE_XO_USER='$USER'" >> creds.sh
	echo "export ANSIBLE_XO_PASSWORD='$PASS'" >> creds.sh
fi