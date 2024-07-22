#!/bin/bash
# vim: ai ts=2 sw=2 et sts=2 ft=sh

config=/opt/ftpd/glftpd/bin/bob-backup.conf

# load configuration
if [ -z "$config" ]; then
  echo "Error. You must specify the location of the config at the top of bob-space.sh."
  exit 1
fi
if [ ! -e "$config" ]; then
  echo "Error. The configuration can not be read: $config" 
  exit 1
fi
. ${config}

#

DATE=`date +%F`

# CLEAN UP FOR MAX FILES
OLDEST=`ls -1t ${DESTDIR} | grep -n ${SITENAME}. | grep ${MAXFILES}: | sed s/${MAXFILES}://`
while [ "${OLDEST}" != "" ]; do
  rm ${DESTDIR}/${OLDEST}
  OLDEST=`ls -1t ${DESTDIR} | grep -n ${SITENAME}. | grep ${MAXFILES}: | sed s/${MAXFILES}://`
done


mkdir ${DESTDIR}/${SITENAME}.${DATE}

# GLROOT directories
for dir in users groups misc; do
  tar -cf ${DESTDIR}/${SITENAME}.${DATE}/${dir}.${DATE}.tar ${GLROOT}/ftp-data/${dir} > /dev/null 2>&1
  gzip ${DESTDIR}/${SITENAME}.${DATE}/${dir}.${DATE}.tar > /dev/null 2>&1
done

for dir in bin etc; do
  tar -cf ${DESTDIR}/${SITENAME}.${DATE}/${dir}.${DATE}.tar ${GLROOT}/${dir} > /dev/null 2>&1
  gzip ${DESTDIR}/${SITENAME}.${DATE}/${dir}.${DATE}.tar > /dev/null 2>&1
done

#SYSTEMDIR (includes ifconfig services crons and iptables)
rm ${SYSTEMDIR}/ifconfig ${SYSTEMDIR}/services ${SYSTEMDIR}/root.cron ${SYSTEMDIR}/${BOTUSERNAME}.cron ${SYSTEMDIR}/iptables ${SYSTEMDIR}/fstab ${SYSTEMDIR}/crypttab
/usr/sbin/ip addr >> ${SYSTEMDIR}/ifconfig
cp /etc/services ${SYSTEMDIR}/services
crontab -l -u root >> ${SYSTEMDIR}/root.cron
crontab -l -u ${BOTUSERNAME} >> ${SYSTEMDIR}/${BOTUSERNAME}.cron
/sbin/iptables-save >> ${SYSTEMDIR}/iptables
cp /etc/fstab ${SYSTEMDIR}/fstab
cp /etc/crypttab ${SYSTEMDIR}/crypttab
tar -cf ${DESTDIR}/${SITENAME}.${DATE}/system.${DATE}.tar ${SYSTEMDIR} > /dev/null 2>&1
gzip ${DESTDIR}/${SITENAME}.${DATE}/system.${DATE}.tar > /dev/null 2>&1

# BOTDIRS AND FILES
for bot in `echo ${BOTDIRS}`; do

  NAME=`echo ${bot} | cut -d ":" -f1 | rev | cut -d "/" -f1 | rev`
  BOTPATH=`echo ${bot} | cut -d ":" -f1`
  BOTSCRIPTS=`echo ${bot} | cut -d ":" -f2`
  BOTCONF=`echo ${bot} | cut -d ":" -f3`
  BOTUSERS=`echo ${bot} | cut -d ":" -f4`
  BOTCHANS=`echo ${bot} | cut -d ":" -f5`

  # BOTSCRIPTS
  tar -cf ${DESTDIR}/${SITENAME}.${DATE}/${NAME}scripts.${DATE}.tar ${BOTPATH}/${BOTSCRIPTS} > /dev/null 2>&1
  gzip ${DESTDIR}/${SITENAME}.${DATE}/${NAME}scripts.${DATE}.tar > /dev/null 2>&1
  # BOT FILES
  cp ${BOTPATH}/${BOTCONF} ${DESTDIR}/${SITENAME}.${DATE}/${NAME}.${BOTCONF}
  cp ${BOTPATH}/${BOTUSERS} ${DESTDIR}/${SITENAME}.${DATE}/${NAME}.${BOTUSERS}
  cp ${BOTPATH}/${BOTCHANS} ${DESTDIR}/${SITENAME}.${DATE}/${NAME}.${BOTCHANS}
done

# GL/PZS-NG FILES
cp ${GLCONF} ${DESTDIR}/${SITENAME}.${DATE}/
cp ${ZSCONF} ${DESTDIR}/${SITENAME}.${DATE}/

cd ${DESTDIR}
tar -cf ${SITENAME}.${DATE}.tar ${SITENAME}.${DATE}/ > /dev/null 2>&1
gzip ${SITENAME}.${DATE}.tar > /dev/null 2>&1

chmod ${MODTAR} ${SITENAME}.${DATE}.tar.gz

rm -rf ${DESTDIR}/${SITENAME}.${DATE}/
