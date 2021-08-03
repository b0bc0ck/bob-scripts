#!/bin/bash

proc_out() {
  echo `date +"%a %b %d %H:%M:%S %Y"` PUB: \"inc\" \"$@\"  >> /home/ftpd/glftpd/ftp-data/logs/glftpd.log
}


if [ ! -f /tmp/bob-incomplete.lock ]; then
  touch /tmp/bob-incomplete.lock
else
  echo "Lock file exists, exiting."
  exit 0
fi

/home/ftpd/glftpd/bin/incomplete-list.sh | while IFS='' read -r line || [[ -n $line ]]; do

    if [ "${line}" != "No more incompletes found." ]; then
      output=`echo $line | cut -d " " -f2-`
      proc_out "$output"
    fi
done
rm /tmp/bob-incomplete.lock
