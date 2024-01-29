#!/bin/bash
echo 'Cron started, running ytdl-sub...'
ytdl-sub --config=/config/config.yaml sub /config/subscriptions.yaml -l verbose
echo 'Finished running ytdl-sub'
