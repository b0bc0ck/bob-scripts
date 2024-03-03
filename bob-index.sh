#!/bin/bash

if [[ -z "$@" ]]; then
        echo ""
        echo "Syntax: site search <item>"
        echo ""
        exit 0
fi

if [ "${1}" == "+links" ]; then
        if [ ! -d "/site/_search_links" ]; then
                echo "Folder /_search_links does not exist..."
                exit 0
        fi
        if [ ! -d "/site/_search_links/${USER}" ]; then
                mkdir -p "/site/_search_links/${USER}"
        else
                rm -rf "/site/_search_links/${USER}"
                mkdir -p "/site/_search_links/${USER}"
        fi
        cd "/site/_search_links/${USER}"
        /bin/scripts/bob-index -G /ftp-data/bob/ -D bob-index.db -M search -l ${USER} -s "${*:2}"
else
        /bin/scripts/bob-index -G /ftp-data/bob/ -D bob-index.db -M search -s "$@"
fi
