#!/bin/bash  -ex
set +x;

source /etc/backup_credentials.sh

sync
pushd /tmp

# Use a | as a separator
exclude_dbs='information_schema|mysql|performance_schema'

back_up_databases

tar -cpJf /tmp/backup_files.tar.xz /var/www/html/

date > /tmp/backup_summary.txt

if md5sum -c /tmp/backup_files.md5
then
    echo "Backupfile not changed. Not updating." >>/tmp/backup_summary.txt
else
    AWS_MAX_ATTEMPTS=10 aws s3 $ENDPOINT --no-progress cp /tmp/backup_files.tar.xz s3://$BACKUP_BUCKET/
    if [ $? -eq 0 ]
    then
        md5sum /tmp/backup_files.tar.xz > /tmp/backup_files.md5
    else
        echo "[Error] Failed uploading backup file to storage."
    fi
fi

AWS_MAX_ATTEMPTS=10 aws s3 $ENDPOINT --no-progress cp /tmp/backup_databases.tar.xz s3://$BACKUP_BUCKET/
AWS_MAX_ATTEMPTS=10 aws s3 $ENDPOINT --no-progress cp /etc/db_pswd.json s3://$BACKUP_BUCKET/
AWS_MAX_ATTEMPTS=10 aws s3 $ENDPOINT --no-progress cp /tmp/backup_summary.txt s3://$BACKUP_BUCKET/

popd
