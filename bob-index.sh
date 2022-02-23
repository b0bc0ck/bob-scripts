#!/bin/bash

if [[ -z "$@" ]]; then
        echo ""
        echo "Syntax: site search <item>"
        echo ""
        exit 0
fi

/bin/bob-index -G /ftp-data/bob/ -D bob-index.db -M search -s "$@"
