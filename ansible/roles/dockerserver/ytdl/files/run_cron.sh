#!/bin/bash
echo 'Cron started, running ytdl-sub...'
ytdl-sub --config=/config/config.yaml sub /config/subscriptions.yaml
echo 'Finished running ytdl-sub'
