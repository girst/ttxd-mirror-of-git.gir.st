#!/bin/sh

if [[ $UID -ne 0 ]]
then	echo "must be root"
	exit 1
fi

sh -c 'cd ./src/dvbtext-src/; make'
sh -c 'cd ./src/thttpd-2.27/; make'
sh -c 'cd ./src/szap-s2/; make'
cp ./src/dvbtext-src/dvbtext .
cp ./src/thttpd-2.27/thttpd .
cp ./src/szap-s2/tzap-t2 .
cp ./ttxd.service /etc/systemd/system/
systemctl enable ttxd.service
