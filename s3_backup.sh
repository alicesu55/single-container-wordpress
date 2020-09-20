#!/bin/bash
set -eux

source /etc/backup_credentials.sh

# These exports are not in backup_credentials.sh, in order to keep the generated
# file short
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_REGION=$AWS_REGION
export AWS_DEFAULT_REGION='us-west-1'

mysqldump --all-databases --single-transaction --user=root --password=$DB_PASSWORD | gzip -9 > /tmp/backup_databases.sql.gz

tar -cpzf /tmp/backup_files.tar.gz /var/www/html/

# to restore,  do sudo tar -cpvzf /tmp/backup_files.tar.gz /var/www/html/


aws configure list

aws s3 cp /tmp/backup_databases.sql.gz s3://$BACKUP_BUCKET/
aws s3 cp /tmp/backup_files.tar.gz s3://$BACKUP_BUCKET/
