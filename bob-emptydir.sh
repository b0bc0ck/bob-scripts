#!/bin/bash
# vim: ai ts=2 sw=2 et sts=2 ft=sh

glroot="/home/ftpd/glftpd"

checkdirs="MP3:/mp3"

#

proc_out() {
  echo `date +"%a %b %d %H:%M:%S %Y"` PUB: \"empty\" \"$@\"  >> ${glroot}/ftp-data/logs/glftpd.log
  echo $@
}

if [ ! -f /tmp/bob-emptydir.lock ]; then
  touch /tmp/bob-emptydir.lock
else
  echo "Lock file exists, exiting."
  exit 0
fi

for i in ${checkdirs}; do
  section=`echo "${i}" | cut -d ":" -f 1`
  directory=`echo "${i}" | cut -d ":" -f 2`
  for empty in `find "${glroot}/site${directory}" -mindepth 1 -maxdepth 2 -type d -empty`; do
    emptydir=`echo ${empty} | sed -e "s:${glroot}/site::g"`
    testit=`echo ${emptydir} | grep '\/[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]$\|\/[0-9][0-9][0-9][0-9]-[0-5][0-9]$'`
    if [ "${testit}" == "" ]; then
      proc_out "${emptydir}"
    fi
  done
done

rm /tmp/bob-emptydir.lock
