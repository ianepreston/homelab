#!/bin/env bash
# Change the remote host and sr_name lines if you want to deploy to a different host
if [ ! -f creds.sh ]; then
	echo "Credentials file doesn't already exist, loading from Bitwarden."
	echo "Logging into bitwarden"
	bw login
	echo "Getting the xen orchestra creds"
	touch creds.sh
	USER=ipreston
	PASS=$(bw get password xo.ipreston.net)
	echo "XOUSER='$USER'" >> creds.sh
	echo "XOPASS='$PASS'" >> creds.sh
fi
