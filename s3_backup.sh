#!/bin/bash
set -eux

source /etc/backup_credentials.sh

sync

# Use a | as a separator
exclude_dbs='information_schema|mysql|performance_schema'

back_up_databases

tar -cpzf /tmp/backup_files.tar.gz /var/www/html/

aws configure list

aws s3 $ENDPOINT cp /tmp/backup_databases.sql.gz s3://$BACKUP_BUCKET/
aws s3 $ENDPOINT cp /tmp/backup_files.tar.gz s3://$BACKUP_BUCKET/
aws s3 $ENDPOINT cp /etc/db_pswd.json s3://$BACKUP_BUCKET/
