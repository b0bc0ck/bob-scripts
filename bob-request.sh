#!/bin/bash
# vim: tabstop=4 shiftwidth=4 softtabstop=4 expandtab:

#
glroot="/opt/ftpd/glftpd"
reqfolder="/requests"
requestprefix="[request]-"
filledprefix="[filled]-"

# are we running chrooted in gl?
if [ -z "`echo ${PWD} | grep ${glroot}`" ]; then
    logfile="/ftp-data/logs/glftpd.log"
    reqfile="/ftp-data/bob/bob-request"
    reqfolderfull="/site${reqfolder}"
    chrooted=true
else
    logfile="${glroot}/ftp-data/logs/glftpd.log"
    reqfile="${glroot}/ftp-data/bob/bob-request"
    reqfolderfull="${glroot}/site${reqfolder}"
    chrooted=false
fi

# if reqfile doesnt exist initialize it
if [ ! -f "${reqfile}" ]; then
    touch "${reqfile}"
    chmod 666 "${reqfile}"
fi

pubout() {
   echo `date "+%a %b %e %T %Y"` PUB: \"request\" \""${@}\"" >> ${logfile}
}

#
proc_request() {
    testrequest=`grep ^"${1}^" ${reqfile}`
    if [ -z "${testrequest}" ]; then
        echo -e "Requesting ${1}"
        echo "${1}^${USER}^${GROUP}^`date +%s`" >> ${reqfile}
        mkdir "${reqfolderfull}/${requestprefix}${1}"
        pubout "${USER} has requested ${1} please fill it!"
    else
        echo -e "Request for ${1} already exists!"
    fi
}

proc_reqfilled() {
    reqfileline=`cat ${reqfile} | grep ^"${1}^"`
    if [ -z "${reqfileline}" ]; then
        echo "Request ${1} not found!"
        exit 0
    fi
    requser=`echo "${reqfileline}" | cut -d "^" -f2`
    echo -e "Setting ${1} as filled"
    sed -i "/${reqfileline}/d" ${reqfile}
    mv "${reqfolderfull}/${requestprefix}${1}" "${reqfolderfull}/${filledprefix}${1}"
    pubout "${USER} has filled the request ${1} for ${requser}!"
}

proc_status() {
    reqcount=`wc -l ${reqfile} | awk '{print $1}'`
    if [ "${reqcount}" == "0" ]; then
        echo -e "No requests have been made! Make some!"
        exit 0
    fi
    echo -e "Current requests (${reqcount}):"
    while IFS= read -r line; do
        request=`echo "$line" | cut -d "^" -f1`
        user=`echo "$line" | cut -d "^" -f2`
        group=`echo "$line" | cut -d "^" -f3`
        epoch=`echo "$line" | cut -d "^" -f4`
        date=`date -d @${epoch}`
        echo "  ${request} by ${user}/${group} on ${date}"
    done < "${reqfile}"
}

proc_reqdel() {
    reqfileline=`cat ${reqfile} | grep ^"${1}^"`
    if [ -z "${reqfileline}" ]; then
        echo "Request ${1} not found!"
        exit 0
    fi
    requser=`echo "${reqfileline}" | cut -d "^" -f2`
    siteop=`echo "${FLAGS}" | grep "1"`
    if [ "${USER}" != "${requser}" ] && [ -z "${siteop}" ]; then
        echo -e "You are not the user who request this or a siteop! You can not delete the request!"
    else
        echo -e "Deleting request for ${1}"
        sed -i "/${reqfileline}/d" ${reqfile}
        rm -rf "${reqfolderfull}/${requestprefix}${1}"
        pubout "${USER} has removed the request for ${1}"
    fi
}

case "${1}" in
    request)
        proc_request "${2}"
        ;;
    reqfilled)
        proc_reqfilled "${2}"
        ;;
    status)
        proc_status
        ;;
    reqdel)
        proc_reqdel "${2}"
        ;;
    reqwipe)
        proc_reqdel "${2}"
        ;;
esac
