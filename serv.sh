#!/bin/bash

cd /opt/Misc_HTTPd/ttx/

killall tzap-t2 dvbtext

mkdir -p /run/ttxd/spool/{1,2,3,4,5,6,7,8}

./tzap-t2 -a0 -f1 -V -c channels.vdr "ORF1;ORF" &>/dev/null&
sleep 5 # TODO: detect FE_HAS_LOCK

./dvbtext 4015 4005 4055 & # ORF1, ORF2, ORF3
