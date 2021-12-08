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
    #rm $EMAIL_FILE
    exit
fi

if [ -e $LOCK_FILE ] && kill -0 `cat $LOCK_FILE`; then
  exit
fi

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
	expect -c "
          spawn sftp $USER@$HOST
          expect \"password: \"
          send \"${PASSWORD}\r\"
          expect \"sftp>\"
          send \"put '$FILE' '$REMOTE_PATH$REMOTE_DIR'\r\"
          expect \"sftp>\"
          #send \"put ${FILE}\r\"
          #expect \"sftp>\"
          send \"bye\r\"
          expect \"#\"
       "
      done
  fi
done

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

rm -f $LOCK_FILE
#rm $EMAIL_FILE
exit 0

