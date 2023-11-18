#!/bin/bash
# vim: ai ts=2 sw=2 et sts=2 ft=sh

GLROOT="/opt/ftpd/glftpd"
GROUPPATH="/site/groups"
GLPRECONF="/opt/ftpd/glftpd.pre.conf"
GLLOG="${GLROOT}/ftp-data/logs/glftpd.log"
PRECFG="${GLROOT}/etc/pre.cfg"

proc_priv() {
  #echo `date "+%a %b %e %T %Y"` "$@"
  echo `date "+%a %b %e %T %Y"` PRIV: \"affils\" \""$@"\" >> $GLLOG
}

proc_pub() {
  #echo `date "+%a %b %e %T %Y"` "$@"
  echo `date "+%a %b %e %T %Y"` PUB: \"affils\" \""$@"\" >> $GLLOG
}

proc_gl_list() {
  proc_pub `grep "privpath ${GROUPPATH} 1" ${GLPRECONF} | sed -e "s:privpath ${GROUPPATH} 1::g" | sed -e "s:=::g" -e "s:^ ::g"`
}

proc_gl_add() {
  if [ ! -z "`grep " ${GROUPPATH}/${1} " ${GLPRECONF}`" ]; then
    return
  else
    groups=`proc_gl_list | sed -e "s: : =:g"`
    cp ${GLPRECONF} ${GLPRECONF}.bak
    rm ${GLPRECONF}
    cat ${GLPRECONF}.bak | head -n -1 >> ${GLPRECONF}
    rm ${GLPRECONF}.bak
    echo "privpath ${GROUPPATH}/${1} 1 =${1}" >> ${GLPRECONF}
    echo "privpath ${GROUPPATH} 1 =${groups} =${1}" >> ${GLPRECONF}
    proc_priv "Added ${1} in glftpd configuration."
  fi
}

proc_gl_del() {
  if [ -z "`grep " ${GROUPPATH}/${1} " ${GLPRECONF}`" ]; then
    return
  else
    groups=`proc_gl_list`
    rm ${GLPRECONF}
    for group in ${groups}; do
      if [ "${1}" != "${group}" ]; then
        echo "privpath ${GROUPPATH}/${group} 1 =${group}" >> ${GLPRECONF}
        grouplist=`echo "${grouplist} ${group}"`
      fi
    done
    grouplist=`echo ${grouplist} | sed -e "s: : =:g"`
    echo "privpath ${GROUPPATH} 1 =${grouplist}" >> ${GLPRECONF}
    proc_priv "Deleted ${1} in glftpd configuration."
  fi
}

proc_dir_add() {
  if [ -d "${GLROOT}${GROUPPATH}/${1}" ]; then
    return
  fi
  mkdir -p "${GLROOT}${GROUPPATH}/${1}"
  chown 0.0 "${GLROOT}${GROUPPATH}/${1}"
  chmod 777 "${GLROOT}${GROUPPATH}/${1}"
  proc_priv "Created pre directory for ${1}"
}

proc_dir_del() {
  if [ -d "${GLROOT}${GROUPPATH}/${1}" ]; then
    rm -rf "${GLROOT}${GROUPPATH}/${1}"
    proc_priv "Deleted pre directory for ${1}"
  fi
}

proc_foo_list () {
  for line in `grep "section" ${PRECFG} | grep name`; do
    section=`echo ${line} | cut -d "." -f2`
    sections=`echo ${sections} ${section}`
    sectionchars=`echo ${section} | wc -m`
    sectioncharlist=`echo ${sectioncharlist} ${sectionchars}`
  done
  sectionbuf=`echo ${sectioncharlist} | sed -e "s: :\n:g" | sort -n | tail -n1`
  for section in `echo ${sections} | xargs -n1 | sort -u | xargs`; do
    groups=""
    for line in `grep "group" ${PRECFG} | grep allow | grep ${section}`; do
      group=`echo ${line} | cut -d "." -f2`
      groupsections=`echo ${line} | cut -d "=" -f2 | sed -e "s:|: :g"`
      for groupsection in ${groupsections}; do
        if [ "${section}" == "${groupsection}" ]; then
          groups=`echo ${groups} ${group}`
        fi
      done
    done
    groups=`echo ${groups} | xargs -n1 | sort -u | xargs`
    if [ ! -z "$groups" ]; then
      msg=`printf "%-${sectionbuf}s: %s\n" "${section}" "${groups}"`
      proc_pub "${msg}"
    fi
  done
}

proc_foo_add() {
  if [ -z "`grep "group" ${PRECFG} | grep dir | grep ${1}`" ]; then
    # group doesnt exist - add in
    #cat ${PRECFG} | sed -n "/#-start groups-#/,/end groups-#/ p"
    sed -i "/#-end groups-#/i group.${1}.dir=${GROUPPATH}/${1}" ${PRECFG}
    sed -i "/#-end groups-#/i group.${1}.allow=${2}" ${PRECFG}
    proc_priv "${1} added in pre.cfg"
  else
    # group exists - replace only allowed sections?
    cursections=`grep "group" ${PRECFG} | grep allow | grep ${1} | cut -d "=" -f2`
    if [ "${cursections}" != "${2}" ]; then
      proc_priv "${1} exists with section(s) ${cursections} set, modifying them to ${2} in pre.cfg"
      replaceme=`grep "group" ${PRECFG} | grep allow | grep ${1}`
      replaceline="group.${1}.allow=${2}"
      sed -i "s:${replaceme}:${replaceline}:g" ${PRECFG}
    else
      proc_priv "${1} exists with section(s) ${cursections} already set in pre.cfg"
    fi
  fi
}

proc_foo_del() {
  if [ ! -z "`grep "group" ${PRECFG} | grep dir | grep ${1}`" ]; then
    sed -i "/group.${1}.*/d" ${PRECFG}
    proc_priv "Deleted ${1} from pre.cfg"
  fi
}

if [ ! -f "${GLPRECONF}" ]; then
  touch ${GLPRECONF}
fi

case ${1} in
  list)
    proc_foo_list
    ;;
  add)
    if [ -z "${3}" ]; then
      exit 1
    fi
    proc_gl_add ${2}
    proc_dir_add ${2}
    proc_foo_add ${2} "${3}"
    ;;
  del)
    if [ -z "${2}" ]; then
      exit 1
    fi
    proc_gl_del ${2}
    proc_dir_del ${2}
    proc_foo_del ${2}
    ;;
  *)
    proc_gl_list
    ;;
esac
