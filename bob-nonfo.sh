#!/bin/bash
# vim: ai ts=2 sw=2 et sts=2 ft=sh

glroot="/home/ftpd/glftpd"

checkdirs="MP3:/mp3"

#

proc_out() {
  echo `date +"%a %b %d %H:%M:%S %Y"` MP3: \"nonfo\" \"$@\"  >> ${glroot}/ftp-data/logs/glftpd.log
  echo $@
}

if [ ! -f /tmp/bob-nonfo.lock ]; then
  touch /tmp/bob-nonfo.lock
else
  echo "Lock file exists, exiting."
  exit 0
fi

for i in ${checkdirs}; do
  section=`echo "${i}" | cut -d ":" -f 1`
  directory=`echo "${i}" | cut -d ":" -f 2`
  for nonfo in `find "${glroot}/site${directory}" -type l -name "(no-nfo)-*"`; do
    nonfodir=`echo ${nonfo} | sed -e "s:${glroot}/site::g" -e "s:(no-nfo)-::g"`
    proc_out "${nonfodir}"
  done
done

rm /tmp/bob-nonfo.lock
