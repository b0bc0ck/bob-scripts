#!/bin/bash

cd /home/ftpd/source/
wget https://glftpd.io/files/glftpd-LNX-2.11a_1.1.1k_x64.tgz
wget https://ftp.eggheads.org/pub/eggdrop/source/1.9/eggdrop-1.9.1.tar.gz
git clone https://github.com/pzs-ng/pzs-ng.git
adduser --disabled-password sitebot
apt-get install tcl-dev libssl-dev make g++ gcc libsqlite3-tcl zip unzip speedtest-cli tcpd lftp
