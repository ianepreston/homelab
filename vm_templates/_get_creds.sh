#!/bin/env bash
# Change the remote host and sr_name lines if you want to deploy to a different host
if [ ! -f creds.json ]; then
	echo "Credentials file doesn't already exist, loading from Bitwarden."
	echo "Logging into bitwarden"
	# bw login
	echo "Getting the xen orchestra creds"
	touch creds.json
	echo "{" > creds.json
	echo "\"remote_host\": \"d-hpp-1.ipreston.net\"," >> creds.json
	USER=root
	PASS=$(bw get password xo.ipreston.net)
	echo "\"remote_username\": \"$USER\"," >> creds.json
	echo "\"remote_password\": \"$PASS\"," >> creds.json
	echo "\"sr_iso_name\": \"Synology ISOs\"," >> creds.json
	echo "\"sr_name\": \"templates-dhpp1\"" >> creds.json
	echo "}" >> creds.json
fi
