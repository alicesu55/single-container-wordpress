#!/bin/bash
set -eux

source /etc/backup_credentials.sh

sync

# Use a | as a separator
exclude_dbs='information_schema|mysql|performance_schema'

back_up_databases

tar -cpJf /tmp/backup_files.tar.xz /var/www/html/

aws configure list

aws s3 $ENDPOINT --no-progress cp /tmp/backup_databases.tar.xz s3://$BACKUP_BUCKET/
aws s3 $ENDPOINT --no-progress cp /tmp/backup_files.tar.xz s3://$BACKUP_BUCKET/
aws s3 $ENDPOINT --no-progress cp /etc/db_pswd.json s3://$BACKUP_BUCKET/
