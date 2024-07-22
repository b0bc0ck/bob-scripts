#!/bin/bash

# ARGUMENTS:
# ----------
# $1 = Name of the file
# $2 = Actual path to file
# $3 = CRC code of the file
# $PWD = Current Path.

# EXIT CODES:
# -----------
# 0 - Good: Give credit and add to user stats.
# 2 - Bad:  No credit / No stats & file is removed.
# 10-1010 - Same as 2, but glftpd will sleep for exitcode-10 seconds
# note: 127 is reserved, so don't use that. 127 is treated like 1,
# causing glftpd to spit out "script could not be executed".

### SETTINGS
#
# NOTE: entries in the PATHS_CHECK and PATHS_EXCLUDE lists are only separated by space
#

PATH_GLFTPD_LOG="/ftp-data/logs/glftpd.log"

PATH_MKVINFO="/bin/mkvinfo"

DELETE_MKV_FAIL=1                   # set to 1 in order to delete broken mkv files automatically

EXT="${1##*.}"

#
###

# file must end in 'mkv'
if [[ "${EXT}" != "mkv" ]]; then
  # echo "Not an MKV file, ignoring"
  exit 0
fi

if [ -z "${2}" ]; then
  PATH_FILE="${1}"
else
  PATH_FILE="${2}/${1}"
fi

# remove empty files right away
if [ ! -s "${PATH_FILE}" ]; then
  rm "${PATH_FILE}"
  exit 2
fi

# mkvinfo needs LC_ALL to be set
#export LC_ALL=C

EXPECTED=$(${PATH_MKVINFO} -z "${PATH_FILE}" | grep '^+' | sed 's/ data.*//g' | awk '{total += $NF} END{print total}')

# deal with mkv files with broken header information
if [[ $EXPECTED -lt 10000 ]]; then
    EXPECTED=0
fi

# stat might not be portable
# ACTUAL=$(stat -c%s "${PATH_FILE}")

ACTUAL=$(wc -c <"${PATH_FILE}")

TIMESTAMP=`date +"%a %b %-d %T %Y"`

if [[ $EXPECTED == $ACTUAL ]]; then
  #echo "$TIMESTAMP MKV_PASS: \"$PWD\" \"$1\" \"$EXPECTED\" \"$ACTUAL\"" >> $PATH_GLFTPD_LOG
  echo -e "Video file is correct (size: $ACTUAL/$EXPECTED)."
  exit 0
fi

echo "$TIMESTAMP MKV_FAIL: \"$PWD\" \"$1\" \"$EXPECTED\" \"$ACTUAL\"" >> $PATH_GLFTPD_LOG;

if [[ $DELETE_MKV_FAIL == 1 ]] && [[ $EXPECTED -gt 0 ]]; then
  echo -e "Video file is corrupted (expected size: $EXPECTED)."
  rm "${PATH_FILE}"
  exit 2
fi

exit 0
