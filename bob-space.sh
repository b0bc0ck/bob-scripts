#!/bin/bash
# vim: ai ts=2 sw=2 et sts=2 ft=sh

config=/home/ftpd/glftpd/bin/bob-space.conf

#

proc_usage() {
  echo "Usage: $0 [go] [debug] [sanity]"
  exit 1
}

proc_out() {
  echo `date "+%a %b %e %T %Y"` $@
  echo `date "+%a %b %e %T %Y"` PRIV: \"space\" \"$@\" >> $GLLOG
}

proc_debug() {
  if [ "$DEBUG" == "TRUE" ]; then
    echo `date "+%a %b %e %T %Y"` $@
  else
    echo `date "+%a %b %e %T %Y"` $@ >> $LOGFILE
  fi
}

proc_cleanup() {
  if [ -f ${TMP}/bob-space.lock ]; then
    rm ${TMP}/bob-space.lock
  fi
  exit 0
}


proc_check_free() {
  adevdf=`df -Pm | grep ${1}`
  adevfree=`echo ${adevdf} | awk '{print $4}'`
  adevtotal=`echo ${adevdf} | awk '{print $3}'`
  if [ "${adevfree}" -ge "${2}" ]; then
    proc_debug "${1} has enough free space: ${adevfree}/${adevtotal}MB, space will free at ${2}MB or less."
    proc_cleanup
  else
    proc_debug "${tdev} requires free space: ${adevfree}/${adevtotal}MB free. Triggered at ${tdevtrig}MB. Looping until ${tdevstop}MB is free."
  fi
}

proc_check_free_arch() {
  adevdf=`df -Pm ${1} | grep "/"`
  adevfree=`echo ${adevdf} | awk '{print $4}'`
  adevtotal=`echo ${adevdf} | awk '{print $3}'`
  count=0
  while [ "${adevfree}" -lt "${2}" ]; do
    let count=count+1
    if [ "${SANITY}" == "TRUE" ] && [ "$count" == "2" ]; then 
      proc_cleanup
    fi
    if [ "${count}" == "${MAX_LOOP}" ];then
      proc_debug "Maximum loop count of ${MAX_LOOP} reached. Exiting."
      proc_cleanup
    fi
    adevdev=`echo ${adevdf} | awk '{print $1}'`
    checkdf=`df -ha | grep "${adevdev}" | egrep -v "/mnt/share" | awk '{print $6}'`
    checkdfcount=`echo "${checkdf}" | wc -l`
    if [ "${checkdfcount}" -gt "0" ]; then
      for adir in ${checkdf}; do 
        for fa in `echo "${ARCHIVE}" | grep "${adir}"`; do
          fasec=`echo ${fa} | cut -d ":" -f 1`
          fasecpath=`echo ${fa} | cut -d ":" -f 2`
          fasectype=`echo ${fa} | cut -d ":" -f 3`
          proc_debug "${fasec} Processing ${fasecdev}:${fasecpath}:${fasectype}"

          if [ "${fasectype}" == "DATED" ]; then
            aoldestdir=`find ${fasecpath} -mindepth 1 -maxdepth 1 -type d ! -type l | sort -n | head -n 1`
          else
            aoldestdir=`find ${fasecpath} -mindepth 1 -maxdepth 1 -type d ! -type l -printf "%T@ %p\n" | sort -n | head -n 1 | awk '{print $2}'`
          fi
          if [ -z "${aoldestdir}" ]; then
                  continue
          fi
    	    if [ "${fasectype}" == "DATED" ]; then
            adateddir=`echo ${aoldestdir} | rev | cut -d "/" -f 1 | rev`
            acheckdated=`echo ${adateddir} | grep -o "-" | wc -l`
            if [ "${acheckdated}" != "2" ]; then
              if [ "${acheckdated}" = "1" ]; then
                amonth=`echo ${adateddir} | cut -d "-" -f 2`
                alastday=`date -d "${amonth}/1 + 1 month - 1 day" "+%d"`
                adateddir=`echo "${adateddir}-${alastday}"`
              else
                proc_out "Dated directory ${adateddir} not recognized as a valid date. Exiting."
                proc_debug "Dated directory ${adateddir} not recognized as a valid date. Exiting."
                proc_cleanup
                exit 1
              fi
            fi
            aepochdir=`date --date="${adateddir} 23:59:59" +"%s"`
            echo ${aepochdir}:${fasec}:${aoldestdir} >> ${TMP}/bob-space.oldlista
          else
            aepochdir=`stat -c%Y ${aoldestdir}`
            echo ${aepochdir}:${fasec}:${aoldestdir} >> ${TMP}/bob-space.oldlista
          fi
        done
      done
      deleteme=`cat ${TMP}/bob-space.oldlista | sort -n | head -n1`
      rm ${TMP}/bob-space.oldlista
      adsec=`echo ${deleteme} | cut -d ":" -f2`
      adoldest=`echo ${deleteme} | cut -d ":" -f3`
      proc_debug "Oldest directory found in ${adsec} archive: ${adoldest}"
      if [ "${GO}" == "TRUE" ]; then
        adoldestdir=`echo "${adoldest}" | rev | cut -d "/" -f1 | rev`
        if [ "${DELFROMARCH}" == "TRUE" ]; then
          rm -rf ${adoldest} && proc_out "removed ${adoldestdir} from ${adsec} archive"
        else
          proc_out "${adsec} archive requires space! maybe try removing ${adoldestdir}"
        fi
      fi
    fi
  adevfree=`df -Pm ${1} | grep "/" | awk '{print $4}'`
  done
}

proc_load_config() {
  if [ -z "$config" ]; then
    echo "Error. You must specify the location of the config at the top of bob-space.sh."
    exit 1
  fi
  if [ ! -e "$config" ]; then
    echo "Error. The configuration can not be read: $config" 
    exit 1
  fi
  . ${config}
  if [ "${DEBUG}" == "TRUE" ]; then
    echo "TMP: ${TMP}"
  fi
}

proc_lock() {
  if [ -f ${TMP}/bob-space.lock ]; then
    proc_out "Error: ${TMP}/bob-space.lock exists."
    exit 1
  else
    touch ${TMP}/bob-space.lock
  fi
}

proc_main() {
  for t in ${TRIGGER}; do
    tdev=`echo ${t} | cut -d ":" -f 1`
    if [ "${tdev}" == "AGE" ]; then
      tdevtrig=`echo ${t} | cut -d ":" -f 2`
      proc_age_mode  ${tdevtrig}
    else
      tdevtrig=`echo ${t} | cut -d ":" -f 2`
      tdevstop=`echo ${t} | cut -d ":" -f 3`
      proc_free_mode ${tdev} ${tdevtrig} ${tdevstop}
    fi
  done
}

proc_age_mode () {
  proc_out "Trigger by age (more than ${tdevtrig} minutes old) running..."
  for i in ${INCOMING}; do
    isec=`echo ${i} | cut -d ":" -f 1`
    isecdev=`echo ${i} | cut -d ":" -f 2`
    isecpath=`echo ${i} | cut -d ":" -f 3`
    isectype=`echo ${i} | cut -d ":" -f 4`
    proc_debug "${isec} Processing ${isecdev}:${isecpath}:${isectype}"
    if [ "${isectype}" == "DATED" ]; then
      proc_debug "Dated dirs should be treated as dated dirs (perhaps another entry in conf for how many days we want to keep in age mode)"
    else
      excludedirs=`find ${isecpath} -mindepth 1 -maxdepth 1 -type l -name "(incomplete)-*" | sed -e "s:(incomplete)-::g" | sed -e "s:^:-not ( -path :g" | sed -e "s:$: -prune ):g" | tr '\n' ' '`
      movedirs=`find ${isecpath} -mindepth 1 -maxdepth 1 ${excludedirs} -type d ! -type l -mmin +${tdevtrig}`
    fi
    if [ -z "${movedirs}" ]; then
      continue
    fi
    for release in ${movedirs}; do
	    releasename=`echo "${release}" | rev | cut -d "/" -f1 | rev`
	    isecarch=`grep -Po ${isec} <<< ${ARCHIVE}`
	    if [ -z "${isecarch}" ]; then
	      proc_debug "${isec} No archive found, deleting ${release}"
	      if [ "${GO}" == "TRUE" ]; then
	        rm -rf ${release} && proc_out "removed ${namerelease} from ${isec}"
	      fi
	    else
	      proc_debug "${isec} Archive found, preparing rsync ${releasename}"
	      for a in ${ARCHIVE}; do
	              asec=`echo ${a} | cut -d ":" -f 1`
	              asecpath=`echo ${a} | cut -d ":" -f 2`
	              asectype=`echo ${a} | cut -d ":" -f 3`
	              if [ "${isec}" == "${asec}" ]; then
	                yearmacro=`echo "${asecpath}" | grep "%YYYY"`
	                if [ ! -z "${yearmacro}" ]; then
	                  replaceyear=`echo ${release} | rev | cut -d "/" -f 1 | rev | cut -d "-" -f1`
	                  asecpath=`echo "${asecpath}" | sed -e "s:%YYYY:${replaceyear}:g"`
	                fi
	                proc_debug "rsync ${RSYNCFLAGS} ${release} ${asecpath}"
	                if [ "${GO}" == "TRUE" ]; then
	                  relsizeh=`du -sh ${release} | awk '{print $1}'`
	                  relsizem=`du -sBm ${release} | awk '{print $1}' | sed -e "s:M::g"`
	                  proc_check_free_arch "${asecpath}" "${relsizem}"
	                  proc_debug "${asecpath}" "${relsizem}"
	                  starttime=`date +%s` && rsync ${RSYNCFLAGS} ${release} ${asecpath} && rsync ${RSYNCFLAGS} ${release} ${asecpath} && endtime=`date +%s` && rm -rf ${release} && totaltime=$(( (endtime - starttime) )) && if [ "${totaltime}" = 0 ]; then totaltime="1";fi && speed=$(( (relsizem / totaltime) )) && proc_out "moved ${releasename} to ${isec} archive - ${relsizeh} in ${totaltime}sec at ${speed}MB/s "
	                fi
              fi
      done
			fi
    done
  done
  proc_cleanup
}

proc_free_mode() {
  proc_out "Trigger by free space running..."
  proc_check_free ${tdev} ${tdevtrig}
  count=0
  while [ "${adevfree}" -lt "${tdevtrig}" ]; do
    let count=count+1
    if [ "${SANITY}" == "TRUE" ] && [ "$count" == "2" ]; then 
      proc_cleanup
    fi
    if [ "${count}" == "${MAX_LOOP}" ];then
      proc_debug "Maximum loop count of ${MAX_LOOP} reached. Exiting."
      proc_cleanup
    fi
    for i in ${INCOMING}; do
      isec=`echo ${i} | cut -d ":" -f 1`
      isecdev=`echo ${i} | cut -d ":" -f 2`
      isecpath=`echo ${i} | cut -d ":" -f 3`
      isectype=`echo ${i} | cut -d ":" -f 4`
      proc_debug "${isec} Processing ${isecdev}:${isecpath}:${isectype}"
      if [ "${isectype}" == "DATED" ]; then
        oldestdir=`find ${isecpath} -mindepth 1 -maxdepth 1 -type d ! -type l | sort -n | head -n 1`
      else
        excludedirs=`find ${isecpath} -mindepth 1 -maxdepth 1 -type l -name "(incomplete)-*" | sed -e "s:(incomplete)-::g" | sed -e "s:^:-not ( -path :g" | sed -e "s:$: -prune ):g" | tr '\n' ' '`
        oldestdir=`find ${isecpath} -mindepth 1 -maxdepth 1 ${excludedirs} -type d ! -type l -printf "%T@ %p\n" | sort -n | head -n 1 | awk '{print $2}'`
      fi
      if [ -z "${oldestdir}" ]; then
        continue
      fi
      if [ "${isectype}" == "DATED" ]; then
        dateddir=`echo ${oldestdir} | rev | cut -d "/" -f 1 | rev`
        checkdated=`echo ${dateddir} | grep -o "-" | wc -l`
        if [ "${checkdated}" != "2" ]; then
          if [ "${checkdated}" = "1" ]; then
            month=`echo ${dateddir} | cut -d "-" -f 2`
            lastday=`date -d "${month}/1 + 1 month - 1 day" "+%d"`
            dateddir=`echo "${dateddir}-${lastday}"`
          else
            proc_out "Dated directory ${dateddir} not recognized as a valid date. Exiting."
            proc_debug "Dated directory ${dateddir} not recognized as a valid date. Exiting."
            proc_cleanup
            exit 1
          fi
        fi
        epochdir=`date --date="${dateddir} 23:59:59" +"%s"`
        echo ${epochdir}:${isec}:${oldestdir} >> ${TMP}/bob-space.oldlist
      else
        epochdir=`stat -c%Y ${oldestdir}`
        echo ${epochdir}:${isec}:${oldestdir} >> ${TMP}/bob-space.oldlist
      fi
    done
    deleteme=`cat ${TMP}/bob-space.oldlist | sort -n | head -n1`
    rm ${TMP}/bob-space.oldlist
    dsec=`echo ${deleteme} | cut -d ":" -f2`
    doldest=`echo ${deleteme} | cut -d ":" -f3`
    proc_debug "Oldest directory found in ${dsec}: ${doldest}"
    isecarch=`grep -Po ${dsec} <<< ${ARCHIVE}`
    if [ -z "${isecarch}" ]; then
      proc_debug "${dsec} No archive found, deleting ${doldest}"
      if [ "${GO}" == "TRUE" ]; then
        doldestdir=`echo "${doldest}" | rev | cut -d "/" -f1 | rev`
        rm -rf ${doldest} && proc_out "removed ${doldestdir} from ${dsec}"
      fi
    else
      proc_debug "${dsec} Archive found, preparing rsync ${doldest}"
      for a in ${ARCHIVE}; do
              asec=`echo ${a} | cut -d ":" -f 1`
              asecpath=`echo ${a} | cut -d ":" -f 2`
              asectype=`echo ${a} | cut -d ":" -f 3`
              if [ "${dsec}" == "${asec}" ]; then
                yearmacro=`echo "${asecpath}" | grep "%YYYY"`
                if [ ! -z "${yearmacro}" ]; then
                  replaceyear=`echo ${doldest} | rev | cut -d "/" -f 1 | rev | cut -d "-" -f1`
                  asecpath=`echo "${asecpath}" | sed -e "s:%YYYY:${replaceyear}:g"`
                fi
                proc_debug "rsync ${RSYNCFLAGS} ${doldest} ${asecpath}"
                if [ "${GO}" == "TRUE" ]; then
                  doldestdir=`echo "${doldest}" | rev | cut -d "/" -f1 | rev`
                  relsizeh=`du -sh ${doldest} | awk '{print $1}'`
                  relsizem=`du -sBm ${doldest} | awk '{print $1}' | sed -e "s:M::g"`
                  proc_check_free_arch "${asecpath}" "${relsizem}"
                  proc_debug "${asecpath}" "${relsizem}"
                  starttime=`date +%s` && rsync ${RSYNCFLAGS} ${doldest} ${asecpath} && rsync ${RSYNCFLAGS} ${doldest} ${asecpath} && endtime=`date +%s` && rm -rf ${doldest} && totaltime=$(( (endtime - starttime) )) && if [ "${totaltime}" = 0 ]; then totaltime="1";fi && speed=$(( (relsizem / totaltime) )) && proc_out "moved ${doldestdir} to ${dsec} archive - ${relsizeh} in ${totaltime}sec at ${speed}MB/s "
                fi
              fi
      done
    fi
    proc_check_free ${tdev} ${tdevtrig}
  done
}


if [ -z "$1" ]; then
  proc_usage
fi

for i in "$@"; do
  case $i in
    go)
      GO="TRUE"
      ;;
    sanity)
      SANITY="TRUE"
      proc_debug "Starting in sanity mode."
      ;;
    debug)
      DEBUG="TRUE"
      ;;
    *)
      proc_usage
      ;;
  esac
done



proc_load_config
proc_lock
proc_main
proc_cleanup
