#!/usr/bin/env bash

# Hey Curious Dev,
#
# This script exists to execute the Matomo cron with the help of environment variables
# Environment variables like the API key wouldn't be possible direct from crontab
#
# P.S. This cronfile runs every minute
#
# - Jonathon Byrdziak

# load the environment variables
source /var/www/html/.env

for file in /var/www/html/cron.d/*.sh
do
   filename=$(basename "$file")
   chmod +x "$file"
  "$file" >> /var/log/cron/"$filename".log 2>&1
done
