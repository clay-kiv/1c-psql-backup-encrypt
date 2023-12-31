#!/bin/bash
#Ping to cheking start script
curl -m 10 --retry 5 https://hc-ping.com/gVeC5_elJFMwq-RQ8pDWbA/1c-backup-psql-dump/start

set -e

PSQL_HOST=localhost
PSQL_USER=postgres
BACKUP_DIR="/root/backup-psql"
GPG_EMAIL=vladimir@kiv.md
GDRIVE_PATH="backup-google:/1cdb/psql_backups-1cdb"
DATE=$(date +%Y_%m_%d-%H_%M)


DATABASES=$(psql -h localhost -U postgres -l -t -w | cut -d '|' -f 1 | sed -e 's/^[[:space:]]*//' | grep -v -E "postgres|template0|template1")


for DB in $DATABASES
do
    pg_dump -h $PSQL_HOST -U $PSQL_USER -v -d $DB | gzip -c > $BACKUP_DIR/$DB.sql.gz

    gpg --encrypt -r $GPG_EMAIL --batch --yes --trust-model always -o $BACKUP_DIR/$DB-$DATE.sql.gz.gpg - < $BACKUP_DIR/$DB.sql.gz && rm -rf $BACKUP_DIR/$DB.sql.gz

    rclone copy -P $BACKUP_DIR/$DB-$DATE.sql.gz.gpg $GDRIVE_PATH/$(date +%Y_%m_%d) && rm -rf $BACKUP_DIR/$DB-$DATE.sql.gz.gpg
done

#Ping to cheking if script finished backup.
curl -m 10 --retry 5 https://hc-ping.com/gVeC5_elJFMwq-RQ8pDWbA/1c-backup-psql-dump

echo "Backups completed!"