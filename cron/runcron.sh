#!/bin/bash

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
  ./"$file" >> /var/log/cron/"$file".log
done
