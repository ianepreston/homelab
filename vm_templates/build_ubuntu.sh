#!/bin/env bash
bash _get_creds.sh
source creds.sh
if [ ! -f /tmp/focal-server-cloudimg-amd64.img ]; then
	wget -O /tmp/focal-server-cloudimg-amd64.img https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
fi

if [ ! -f /tmp/focal-server-cloudimg-amd64.vhd ]; then
	qemu-img convert -f qcow2 /tmp/focal-server-cloudimg-amd64.img -O vpc /tmp/focal-server-cloudimg-amd64.vhd
fi

xo-cli --register --allowUnauthorized http://xo.ipreston.net $XOUSER $XOPASS