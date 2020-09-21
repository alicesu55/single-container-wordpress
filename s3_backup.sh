#!/bin/bash
set -eux

source /etc/backup_credentials.sh

sync

# These exports are not in backup_credentials.sh, in order to keep the generated
# file short
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_REGION=$AWS_REGION
export AWS_DEFAULT_REGION='us-west-1'

# Use a | as a separator
exclude_dbs='information_schema|mysql|performance_schema'

mysqldump --user=root --password=$DB_PASSWORD --databases $(mysql --user=root --password=$DB_PASSWORD -rs -e 'SHOW DATABASES;' | tail -n+1 | grep -v -E '^('$exclude_dbs')$') | gzip -9 > /tmp/backup_databases.sql.gz

#mysqldump --all-databases --single-transaction --user=root --password=$DB_PASSWORD | gzip -9 > /tmp/backup_databases.sql.gz
#mysqldump --all-databases --single-transaction --quick --lock-tables=false --user=root --password=$DB_PASSWORD | gzip -9 > /tmp/backup_databases.sql.gz

tar -cpzf /tmp/backup_files.tar.gz /var/www/html/

aws configure list

aws s3 cp /tmp/backup_databases.sql.gz s3://$BACKUP_BUCKET/
aws s3 cp /tmp/backup_files.tar.gz s3://$BACKUP_BUCKET/
