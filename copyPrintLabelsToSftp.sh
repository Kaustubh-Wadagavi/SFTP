#!/bin/bash

CONFIG_FILE=$1
current_time=$(date "+%Y.%m.%d-%H.%M.%S")

sendEmail() {
  curl --ssl-reqd --url 'smtps://smtp.gmail.com:465' -u $EMAIL_ID:$EMAIL_PASS --mail-from $EMAIL_ID --mail-rcpt $RCPT_EMAIL_ID --upload-file $EMAIL_LOG_FILE_PATH/$current_time.log

}

moveFiles() {
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
   
  rm -f $TEMP_FILE
  rm -f $LOCK_FILE
  exit 0;

}

transferFiles() {
  echo "quit" >> $TEMP_FILE
  expect -c " 
    set timeout 300  
    spawn sftp -o "BatchMode=no" -b "$TEMP_FILE" -v "$USER@$HOST"
    expect \"password: \"
    send \"${PASSWORD}\r\"
    expect eof
  " >> $EMAIL_LOG_FILE_PATH/$current_time.log
  
  SFTP_EXIT_CODE=$?
  echo "SFTP EXIT CODE IS: $SFTP_EXIT_CODE" >> $EMAIL_LOG_FILE_PATH/$current_time.log
  
  if [[ $SFTP_EXIT_CODE -eq 0 ]]
  then
    echo "Files are uploaded successfully" >> $EMAIL_LOG_FILE_PATH/$current_time.log
    moveFiles
  else
    sendEmail
  fi

}

startLog() {
  cat > $EMAIL_LOG_FILE_PATH/$current_time.log << EOF
Subject: [ IMPORTANT ALERT ] : '$CLIENT_NAME_AND_ENVIRONMENT' : SFTP COPY SCRIPT FAILED!
        
Hello Build Team,
 
Please check the below errors
 
==================================================================================================================

EOF

  echo "$(date +%F-%T)-INFO- Synchronizing: Found files in local folder to upload." >> $EMAIL_LOG_FILE_PATH/$current_time.log
  transferFiles

}

createSftpBatchFile() {
  trap "rm -f $TEMP_FILE" 0 1 15
  trap "rm -f $LOCK_FILE; exit" INT TERM EXIT
  echo $$ > $LOCK_FILE

  find "${SOURCE_DIR}" -maxdepth 1 -type d | while read SUB_DIR
  do
    find "${SUB_DIR}" -maxdepth 1 -type f | while read FILE
    do
      REMOTE_DIR="${SUB_DIR/$SOURCE_DIR}"
      echo "mput '$FILE' '$REMOTE_WORKING_DIR$REMOTE_DIR'" >> $TEMP_FILE
    done
  done

  if [ -s "$TEMP_FILE" ]
  then	    
    startLog
  else
    echo "No files found to transfer" >> $EMAIL_LOG_FILE_PATH/$current_time.log
    rm -f $TEMP_FILE
    rm -f $LOCK_FILE
    exit 0;
  fi

}

if [ ! -f "$CONFIG_FILE" ]
then
  echo "Please input the config file"
  exit 0;
fi

source $CONFIG_FILE
createSftpBatchFile 
