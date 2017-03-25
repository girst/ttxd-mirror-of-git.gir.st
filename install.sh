#!/bin/sh

if [[ $UID -ne 0 ]]
then	echo "must be root"
	exit 1
fi

sh -c 'cd ./src/dvbtext-src/; make'
sh -c 'cd ./src/vtx2ascii-src/; make'
sh -c 'cd ./src/thttpd-2.27/; make'
cp ./src/dvbtext-src/dvbtext .
cp ./src/vtx2ascii-src/vtx2ascii .
cp ./src/thttpd-2.27/thttpd .
cp ./ttxd.service /etc/systemd/system/
systemctl enable ttxd.service
