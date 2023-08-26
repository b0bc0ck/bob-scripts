#!/bin/bash
# script which backups any file to be deleted
# $1 = file or dir to be deleted
# $2 = dir containing the file or dir

if [[ -d "$2/$1" ]]; then
  /bin/bob-index -G /ftp-data/bob/ -D bob-index.db -M delete -p $2 -n $1
fi
