#!/bin/bash

cd /opt/ttxd/

killall tzap dvbtext thttpd

mkdir -p /run/ttxd/spool/{1,2,3,4,5,6,7,8}

tzap -a 0 -c channels.conf ORF1 &>/dev/null&
sleep 5 # TODO: detect FE_HAS_LOCK

./dvbtext 6015 6025 & # 6015=ORF1, 6025=ORF2
./thttpd -p 8080 -d /opt/ttxd/ -c '**.cgi'
