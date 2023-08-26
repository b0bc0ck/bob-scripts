#!/bin/bash
# $1 = Name of directory.
# $2 = Actual path the directory is stored in
# $PWD = Current Path.

# EXIT codes..
# 0 - Good: 
# 2 - Bad:

checkme=""

case $1 in
    Sample)
        if [ -d "$2/sample" ]; then
            exit 2
        fi
	checkme=`echo $2 | grep -iE "/proof|/sample"`
	if [ "${checkme}" != "" ]; then
            exit 2
	fi
	exit 0
        ;;
    sample)
        if [ -d "$2/Sample" ]; then
            exit 2
        fi
	checkme=`echo $2 | grep -iE "/proof|/sample"`
	if [ "${checkme}" != "" ]; then
            exit 2
	fi
	exit 0
        ;;
    Proof)
        if [ -d "$2/proof" ]; then
            exit 2
        fi
	checkme=`echo $2 | grep -iE "/proof|/sample"`
	if [ "${checkme}" != "" ]; then
            exit 2
	fi
	exit 0
        ;;
    proof)
        if [ -d "$2/Proof" ]; then
            exit 2
        fi
	checkme=`echo $2 | grep -iE "/proof|/sample"`
	if [ "${checkme}" != "" ]; then
            exit 2
	fi
	exit 0
        ;;
    *)
        ;;
esac

/bin/bob-index -G /ftp-data/bob/ -D bob-index.db -M predir -s "${1}"
exitcode=`echo "$?"`
if [ "${exitcode}" != "0" ]; then
	exit 2
fi

/bin/bob-index -G /ftp-data/bob/ -D bob-index.db -M add -p "${2}" -n "${1}"
