#!/bin/bash
set -eux

source /etc/backup_credentials.sh

sync

export AWS_DEFAULT_REGION='us-west-1'

# Use a | as a separator
exclude_dbs='information_schema|mysql|performance_schema'

#mysqldump --user=root --password=$DB_PASSWORD --databases $(mysql --user=root --password=$DB_PASSWORD -rs -e 'SHOW DATABASES;' | tail -n+1 | grep -v -E '^('$exclude_dbs')$') | gzip -9 > /tmp/backup_databases.sql.gz
mysqldump --all-databases --single-transaction --user=root --password=$DB_PASSWORD | gzip -9 > /tmp/backup_databases.sql.gz
#mysqldump --all-databases --single-transaction --user=root --password=$DB_PASSWORD | gzip -9 > /tmp/backup_databases.sql.gz
#mysqldump --all-databases --single-transaction --quick --lock-tables=false --user=root --password=$DB_PASSWORD | gzip -9 > /tmp/backup_databases.sql.gz

tar -cpzf /tmp/backup_files.tar.gz /var/www/html/

aws configure list

if [ ! md5sum -c /tmp/backup_databases.sql.gz.md5 ]
then
    aws s3 cp /tmp/backup_databases.sql.gz s3://$BACKUP_BUCKET/
    md5sum /tmp/backup_databases.sql.gz >/tmp/backup_databases.sql.gz.md5
fi

if [ ! md5sum -c /tmp/backup_databases.sql.gz.md5 ]
then
    aws s3 cp /tmp/backup_files.tar.gz s3://$BACKUP_BUCKET/
    md5sum /tmp/backup_files.tar.gz >/tmp/backup_files.tar.gz.md5
fi

if [ ! md5sum -c /etc/db_pswd.json.md5 ]
then
    aws s3 cp /etc/db_pswd.json s3://$BACKUP_BUCKET/
    md5sum /etc/db_pswd.json >/etc/db_pswd.json.md5
fi
