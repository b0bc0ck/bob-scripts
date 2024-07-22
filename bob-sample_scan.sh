#!/bin/bash

#!/bin/bash
#
GLROOT="/home/ftpd1/glftpd"

sections="anime movies series"

for section in ${sections}; do
    rm ${GLROOT}/site/private/organize/bad_samples_${section}.txt
    for sample in `find ${GLROOT}/site/archive/${section}/ -type f -iname *.mkv`; do
        if [ -f "${sample}" ]; then
            expected=$(mkvinfo -z "${sample}" | grep '^+' | sed 's/ data.*//g' | awk '{total += $NF} END{print total}')
            if [[ ${expected} -lt 10000 ]]; then
                expected=0
            fi
            actual=$(wc -c <"${sample}")
            if [[ $expected != $actual ]]; then
                echo "${sample} expected: ${expected} != actual: ${actual}" | sed -e "s:${GLROOT}/site::g" >> ${GLROOT}/site/private/organize/bad_samples_${section}.txt
            fi
        fi
    done
done
