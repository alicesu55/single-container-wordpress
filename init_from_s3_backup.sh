#!/bin/bash -ex
set -eux

source /etc/backup_credentials.sh

aws configure list

if [ "$(mount |grep /var/www/html)" ]; then
    echo "The web directory is not empty. Not restoring from S3"
else
    echo "Web directory is empty, restoring from S3"
    AWS_MAX_ATTEMPTS=10 aws s3 $ENDPOINT cp s3://$BACKUP_BUCKET/backup_files.tar.xz /tmp/backup_files.tar.xz
    md5sum /tmp/backup_files.tar.xz >/tmp/backup_files.md5
    ls -lh /tmp/backup_files.tar.xz
    pv -L 3m /tmp/backup_files.tar.xz | tar Jxf - -C /
    sleep 1
fi

if [ "$(ls /var/lib/mysql)" ]; then
    echo "The database directory is not empty. Not restoring from S3"
else
    echo "The database directory is empty, restoring from S3"
    AWS_MAX_ATTEMPTS=10  aws s3 $ENDPOINT cp s3://$BACKUP_BUCKET/backup_databases.tar.xz /tmp/backup_databases.tar.xz
    pushd /
    tar vJxf /tmp/backup_databases.tar.xz 
    cat /tmp/*.sql > /docker-entrypoint-initdb.d/10-restore_from_s3.sql
    popd
    AWS_MAX_ATTEMPTS=10  aws s3 $ENDPOINT cp s3://$BACKUP_BUCKET/db_pswd.json /etc/db_pswd.json
fi

