#!/bin/bash
set -eux

source /etc/backup_credentials.sh

# These exports are not in backup_credentials.sh, in order to keep the generated
# file short
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_REGION=$AWS_REGION
export AWS_DEFAULT_REGION='us-west-1'

if [ "$(ls -A /var/www/html)" ]; then
    echo "The web directory is not empty. Not restoring from S3"
else
    echo "Web directory is empty, restoring from S3"
    aws s3 cp s3://$BACKUP_BUCKET/backup_files.tar.gz /tmp/backup_files.tar.gz
    ls -lh /tmp/backup_files.tar.gz
    tar -xzf /tmp/backup_files.tar.gz -C /
fi

if [ "$(ls -A /var/lib/mysql)" ]; then
    echo "The database directory is not empty. Not restoring from S3"
     
else
    echo "The datanase directory is empty, restoring from S3"
    aws s3 cp s3://$BACKUP_BUCKET/backup_databases.sql.gz /tmp/backup_databases.sql.gz
    gunzip -c /tmp/backup_databases.sql.gz > /docker-entrypoint-initdb.d/30-restore_from_s3.sql
fi

