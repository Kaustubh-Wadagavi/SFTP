#!/bin/bash

CONFIG_FILE=$1

if [ ! -f "$CONFIG_FILE" ]
then
    echo "Please input the config file"
    exit
fi	

source $CONFIG_FILE

TOTAL_FILE_COUNT=$(find "$SOURCE_DIR" -type f | wc -l)

if [[ $TOTAL_FILE_COUNT -eq 0 ]]
then
    rm $EMAIL_FILE
    exit
fi

if [ -e $TEMP_FILE ] && kill -0 `cat $TEMP_FILE`; then
  exit
fi

trap "rm -f $TEMP_FILE" 0 1 15
trap "rm -f $LOCK_FILE; exit" INT TERM EXIT
echo $$ > $LOCK_FILE

find "${SOURCE_DIR}" -maxdepth 1 -type d | while read SUB_DIR
do 
  SUB_DIR_FILE_COUNT=$(find "$SUB_DIR" -type f | wc -l) 
  if [[ $SUB_DIR_FILE_COUNT -ne 0 ]]
  then
      find "${SUB_DIR}" -maxdepth 1 -type f | while read FILE
      do
	REMOTE_DIR="${SUB_DIR/$SOURCE_DIR}"
        echo "put '$FILE' '$REMOTE_WORKING_DIR$REMOTE_DIR'" >> $TEMP_FILE
      done
  fi
done

echo "quit" >> $TEMP_FILE   

cat > $EMAIL_FILE << EOF
Subject: [ IMPORTATNT ALERT ] : '$CLIENT_NAME_AND_ENVIRONMENT' : SFTP COPY SCRIPT FAILED!
 
Hello Buid Team,
 
Please check the below errors
 
==================================================================================================================
 
EOF

echo "$(date +%F-%T)-INFO- Synchronizing: Found $TOTAL_FILE_COUNT files in local folder to upload." >> $EMAIL_FILE

expect -c " 
  spawn sftp -i /home/krishagni/kaustubh-private -o "BatchMode=no" -b "$TEMP_FILE" -v "$USER@$HOST"
  expect \"password: \"
  send \"${PASSWORD}\r\"
  expect \"sftp>\"
  expect eof
" >> $EMAIL_FILE

SFTP_EXIT_CODE=$?
echo "SFTP EXIT CODE IS: $SFTP_EXIT_CODE" >> $EMAIL_FILE

if [[ $SFTP_EXIT_CODE -eq 0 ]]
then
   echo "$TOTAL_FILE_COUNT files are uploaded successfully." >> $EMAIL_FILE
   find "${SOURCE_DIR}"/* -maxdepth 1 -type d | while read SUB_DIR
   do
      DIR="${SUB_DIR/$SOURCE_DIR}"
       if [ -d "${MOVING_FILES_LOCATION}" ] && [ -d "${MOVING_FILES_LOCATION}${DIR}" ]
       then
	 mv "${SUB_DIR}"/* "${MOVING_FILES_LOCATION}${DIR}"
       else
         mkdir -p "${MOVING_FILES_LOCATION}${DIR}"
         mv "${SUB_DIR}"/* "${MOVING_FILES_LOCATION}${DIR}"
       fi
   done
else
   echo "Script is failed"
   curl --ssl-reqd --url 'smtps://smtp.gmail.com:465' -u $EMAIL_ID:$EMAIL_PASS --mail-from $EMAIL_ID --mail-rcpt $RCPT_EMAIL_ID --upload-file $EMAIL_FILE
fi

#rm -f $TEMP_FILE
#rm -f $LOCK_FILE
#rm $EMAIL_FILE
exit 0