#!/bin/bash
##credentials in pgpass.conf

PSQL_HOST=localhost
PSQL_USR=postgres
PSQL_DB_NAME=bk-$(date +%Y_%m_%d-%H_%M).backup
BACKUP_DIR="/root/backup-psql"
GPG_EMAIL=vladimir@kiv.md
GDRIVE_FOLDER="/1cdb/psql_backups-1cdb"


#Max retries upload file to google drive.
MAX_UPLOAD_RETRIES=4

# List of all db psql
PSQL_DB_LIST=$(psql -h $PSQL_HOST -U $PSQL_USR -l -t -w | cut -d '|' -f 1 | sed -e 's/^[[:space:]]*//')


for PSQL_DB in $PSQL_DB_LIST
do
    if [ "$PSQL_DB" != "template0" ] && [ "$PSQL_DB" != "template1" ] && [ "$PSQL_DB" != "postgres" ]; then
        echo "$(date +%H:%M:%S-%Y_%m_%d) | Dumping db $PSQL_DB"

        #VAR encrpted name db
        ENCRYPT_FILE_NAME=$PSQL_DB-$PSQL_DB_NAME.gpg
        echo $ENCRYPT_FILE_NAME
      
        # Dump PostgreSQL database
        pg_dump -h $PSQL_HOST -U $PSQL_USR -d $PSQL_DB -F c -b -v -f $BACKUP_DIR/$PSQL_DB-$PSQL_DB_NAME
        
        # Encrypt the dump file
        gpg --encrypt -r $GPG_EMAIL --batch --yes --trust-model always -o $BACKUP_DIR/$ENCRYPT_FILE_NAME - < $BACKUP_DIR/$PSQL_DB-$PSQL_DB_NAME

        #Remove dump raw file.
        rm -rf $BACKUP_DIR/$PSQL_DB-$PSQL_DB_NAME
        echo "$(date +%H:%M:%S-%Y_%m_%d) | File $BACKUP_DIR/$PSQL_DB-$PSQL_DB_NAME has ben deleted."

        for UPLOAD_ATTEMPT in $(seq 1 $MAX_UPLOAD_RETRIES); do
            # Upload to Google Drive using rclone
            rclone copy -P $BACKUP_DIR/$ENCRYPT_FILE_NAME backup-google:$GDRIVE_FOLDER
            
            #Check if upload is successful
            if [ $? -eq 0 ]; then
                echo "$(date +%H:%M:%S-%Y_%m_%d) | File successfully upload to Google Drive" 
                
                #MD5 local file sum
                LOCAL_MD5=$(md5sum $BACKUP_DIR/$ENCRYPT_FILE_NAME | awk '{print $1}')
                #MD5 remote file sum
                REMOTE_MD5=$(rclone md5sum backup-google:$GDRIVE_FOLDER/$ENCRYPT_FILE_NAME | awk '{print $1}')

                if [ "$LOCAL_MD5" == "$REMOTE_MD5" ]; then
                    echo "$(date +%H:%M:%S-%Y_%m_%d) | MD5 sum is identical! File from Google Drive is intact."
                    #sleep 5 seconds.
                    sleep 5
                    # Cleanup - remove local encrypted dump file
                    rm -rf $BACKUP_DIR/$ENCRYPT_FILE_NAME
                    echo "$(date +%H:%M:%S-%Y_%m_%d) | File $BACKUP_DIR/$ENCRYPT_FILE_NAME has ben deleted."

                else
                    echo "$(date +%H:%M:%S-%Y_%m_%d) | WARNING: MD5 cheksum does not match for file $ENCRYPT_FILE_NAME. Check the transfer!"
                fi

                #Leave from loop if test successfully terminated.
                break
            else
                echo "$(date +%H:%M:%S-%Y_%m_%d) | ERROR to upload. Attempt $UPLOAD_ATTEMPT / $MAX_UPLOAD_RETRIES."
                if [ $UPLOAD_ATTEMPT -eq $MAX_UPLOAD_RETRIES ]; then
                    echo "$(date +%H:%M:%S-%Y_%m_%d) | ERROR: The maximum number of upload has been reached. Move to next step!"
                    break
                fi
                #sleep 5 seconds.
                sleep 5
            fi
        done
    fi
done

echo "Backups completed!"