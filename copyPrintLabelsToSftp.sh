#!/bin/bash

CONFIG_FILE=$1
CURRENT_TIME=$(date "+%Y.%m.%d-%H.%M.%S")

sendEmail() {
  curl --ssl-reqd --url 'smtps://smtp.gmail.com:465' -u $EMAIL_ID:$EMAIL_PASS --mail-from $EMAIL_ID --mail-rcpt $RCPT_EMAIL_ID --upload-file $EMAIL_LOG_FILE_PATH/$CURRENT_TIME.log

}

moveFiles() {
  while IFS=, read -r FILE_NAME LOCATION
  do
    BASE_DIR=$(dirname $FILE_NAME)
    DIR="${BASE_DIR/$SOURCE_DIR}"
    echo $DIR
    if [ -d "${UPLOADED_FILES_DIR}" ] && [ -d "${UPLOADED_FILES_DIR}/${DIR}" ]
    then
       mv "$FILE_NAME" "${UPLOADED_FILES_DIR}/${DIR}"
    else
       mkdir -p "${UPLOADED_FILES_DIR}/${DIR}"
       mv "$FILE_NAME" "${UPLOADED_FILES_DIR}/${DIR}"
   fi
  done < $FILES_LIST

}

transferFiles() {
  echo "quit" >> $TEMP_FILE
  expect -c " 
    set timeout 300  
    spawn sftp -o "BatchMode=no" -b "$TEMP_FILE" -v "$USER@$HOST"
    expect \"password: \"
    send \"${PASSWORD}\r\"
    expect eof
  " >> $EMAIL_LOG_FILE_PATH/$CURRENT_TIME.log

  SFTP_EXIT_CODE=$?
  echo "SFTP EXIT CODE IS: $SFTP_EXIT_CODE" >> $EMAIL_LOG_FILE_PATH/$CURRENT_TIME.log
  return $SFTP_EXIT_CODE

}

enableLogging() {
  cat > $EMAIL_LOG_FILE_PATH/$CURRENT_TIME.log << EOF
Subject: [ IMPORTANT ALERT ] : '$CLIENT_NAME_AND_ENVIRONMENT' : SFTP COPY SCRIPT FAILED!
        
Hello Build Team,
 
Please check the below errors
 
==================================================================================================================

EOF

  echo "$(date +%F-%T)-INFO- Synchronizing: Found files in local folder to upload." >> $EMAIL_LOG_FILE_PATH/$CURRENT_TIME.log
  
}

generateTransferBatchFile() {
  while IFS=, read -r FILE_NAME LOCATION
  do
    echo "mput '$FILE_NAME' '$LOCATION'" >> $TEMP_FILE
  done < $FILES_LIST

}

getListOfFilesToTransfer() {
  trap "rm -f $TEMP_FILE" 0 1 15
  trap "rm -f $LOCK_FILE; exit" INT TERM EXIT
  echo $$ > $LOCK_FILE

  find "${SOURCE_DIR}" -maxdepth 1 -type d | while read SUB_DIR
  do
    find "${SUB_DIR}" -maxdepth 1 -type f | while read FILE
    do
      REMOTE_DIR="${SUB_DIR/$SOURCE_DIR}"
      echo "$FILE,$REMOTE_WORKING_DIR$REMOTE_DIR" >> $FILES_LIST
    done
  done

}

main() {
  if [ ! -f "$CONFIG_FILE" ]
  then
    echo "Please input the config file"
    exit 0;
  fi

  source $CONFIG_FILE

  getListOfFilesToTransfer

  if [ -s "$FILES_LIST" ]
  then
    generateTransferBatchFile
  else
    echo "No files found to transfer" >> $EMAIL_LOG_FILE_PATH/$CURRENT_TIME.log
    rm -f $FILES_LIST
    rm -f $TEMP_FILE
    rm -f $LOCK_FILE
    exit 0;
  fi

  enableLogging

  transferFiles
  local STATUS=$?

  if [ $STATUS -eq 0 ]
  then
    moveFiles
 #   rm -f $FILES_LIST
 #   rm -f $TEMP_FILE
 #   rm -f $LOCK_FILE
    exit 0;
  else
    sendEmail
  fi

}
   
main;
