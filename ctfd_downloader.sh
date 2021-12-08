#!/bin/bash

function  fname_normalize()
{
  if [ "$1" == "" ]
  then
    cat | nkf -w --url-input | tr '\\/ \t\v\0' '_'
  else
    echo $1 | nkf -w --url-input | tr '\\/ \t\v\0' '_'
  fi
}

function  secure_mkdir()
{
  local DIR=$1
  if [ ! -d $DIR ]
  then
    if [ -e $DIR ]
    then
      echo "\"$DIR\" is not directory." 1>&2
      echo "abort." 1>&2

      exit 1
    fi

    mkdir -p $DIR
  fi
}

if [ "$1" == "" ]
then
  read -p "CTFd BaseURL: " HOST
else
  HOST=$1
fi
HOST=$( echo $HOST | sed "s/\/$//g")
BASEDIR=$( echo $HOST | sed "s/^[^:]*:\/\/\([^\/]*\).*/\1/g" | fname_normalize )
secure_mkdir $BASEDIR

cd $BASEDIR

COOKIE=cookie

ANS="n"
if [ -f $COOKIE ]
then
  echo "Cookie file is existed."
  read -p "Are you sure to use this cookie file?[y/n](default: y) " ANS
fi


if [ "$ANS" == "n" ]
then
  read -p "User Name: " NAME
  read -p "Password: " PASSWORD

  curl -k -c $COOKIE -s https://nssc-challenge.mydns.jp/login -o login.html
  NONCE=$( sed -n 's/.*<input type="hidden" name="nonce" value="\([^"]*\)">.*/\1/gp' login.html )
  curl -k -c $COOKIE -b $COOKIE -L -s https://nssc-challenge.mydns.jp/login -d "name=$NAME&password=$PASSWORD&nonce=$NONCE" -o /dev/null
fi
curl -k -b $COOKIE -s https://nssc-challenge.mydns.jp/chals -o chals.json
curl -k -b $COOKIE -s https://nssc-challenge.mydns.jp/chals/solves -o solves.json

if head -1 chals.json | grep '^<!DOCTYPE html>' > /dev/null
then
  echo "[Warning!!] You might not login your account." >&2
  read -p "Do you remove a cookie file and exit?[y/n](default: y) " ANS
  if [ "$ANS" != "n" ]
  then
    rm $COOKIE

    exit 1
  fi
fi

for DIR in $( cat chals.json | jq -r .game[].category | uniq )
do
  secure_mkdir $( fname_normalize $DIR )
done

for ID in $( cat solves.json | jq -r ". | keys | .[]" )
do
  DIR=$( cat chals.json | jq -r ".game | map(select(.id == "$ID"))[] | .category" | fname_normalize )
  DIR=$DIR/$(cat chals.json | jq -r ".game | map(select(.id == "$ID"))[] | .name" | fname_normalize )
  echo $DIR

  secure_mkdir $DIR
  secure_mkdir $DIR/files

  cat chals.json | jq -r ".game | map(select(.id == "$ID"))[] | .description" > $DIR/description.html
  curl -k -b $COOKIE -s "$HOST/chal/$ID/explanation" -o "$DIR/explanation.json"
  curl -k -b $COOKIE -s "$HOST/chal/$ID/flag" -o "$DIR/flag.json"

  MAX=$( cat chals.json | jq ".game | map(select(.id == "$ID"))[] | .hints | length" )
  IDX=0
  while [ $IDX -lt $MAX ]
  do
    cat chals.json | jq -r ".game | map(select(.id == "$ID"))[] | .hints[$IDX].hint" > $DIR/hint$IDX.html
    IDX=$(( $IDX + 1 ))
  done

  MAX=$( cat chals.json | jq ".game | map(select(.id == "$ID"))[] | .files | length" )
  IDX=0
  while [ $IDX -lt $MAX ]
  do
    FILE=$( cat chals.json | jq -r ".game | map(select(.id == "$ID"))[] | .files[$IDX]" )
    #secure_mkdir $( dirname $FILE )

    OUTFILE=$DIR/files/$( basename $FILE | fname_normalize )
    if [ ! -e "$OUTFILE" ]
    then
      echo " $OUTFILE"
      curl -k -b $COOKIE -s "$HOST/files/$FILE" -o "$OUTFILE"
    fi

    IDX=$(( $IDX + 1 ))
  done

  for FILE in $( cat $DIR/description.html | sed -n 's/.*<a href="\([^"]*\)".*/\1/gp' )
  do
    if ! echo $FILE | grep "^[^:]*://" > /dev/null
    then
      OUTFILE=$DIR/files/$( basename $FILE | fname_normalize )
      if [ ! -e "$OUTFILE" ]
      then
        echo " $OUTFILE"
        curl -k -b $COOKIE -s "$HOST/$FILE" -o "$OUTFILE"
      fi
    fi
  done

  for FILE in $( cat $DIR/description.html | sed -n 's/.*<img[^>]*src="\([^"]*\)".*/\1/gp' )
  do
    if ! echo $FILE | grep "^[^:]*://" > /dev/null
    then
      OUTFILE=$DIR/files/$( basename $FILE | fname_normalize )
      if [ ! -e "$OUTFILE" ]
      then
        echo " $OUTFILE"
        curl -k -b $COOKIE -s "$HOST/$FILE" -o "$OUTFILE"
      fi
    fi
  done

  cat $DIR/explanation.json | jq -r ".explanation[].explanation" > $DIR/explanation.html
  for FILE in $( cat $DIR/explanation.html | sed -n 's/.*<a href="\([^"]*\)".*/\1/gp' )
  do
    if ! echo $FILE | grep "^[^:]*://" > /dev/null
    then
      OUTFILE=$DIR/files/$( basename $FILE | fname_normalize )
      if [ ! -e "$OUTFILE" ]
      then
        echo " $OUTFILE"
        curl -k -b $COOKIE -s "$HOST/$FILE" -o "$OUTFILE"
      fi
    fi
  done

  for FILE in $( cat $DIR/explanation.html | sed -n 's/.*<img[^>]*src="\([^"]*\)".*/\1/gp' )
  do
    if ! echo $FILE | grep "^[^:]*://" > /dev/null
    then
      OUTFILE=$DIR/files/$( basename $FILE | fname_normalize )
      if [ ! -e "$OUTFILE" ]
      then
        echo " $OUTFILE"
        curl -k -b $COOKIE -s "$HOST/$FILE" -o "$OUTFILE"
      fi
    fi
  done

  cat $DIR/flag.json | jq -r ".flag[].flag" > $DIR/flag.html
done
