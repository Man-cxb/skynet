#!/bin/bash

#killall skynet

PIDS=`ps -ef | grep -v grep | grep skynet | awk '{print $2}'`
for PID in $PIDS
do
	kill $PID
	echo "kill $PID"
done

usleep 1000
rm -rf logs
skynet/skynet system/game.config &
sleep 1
pgrep -fl skynet
tail -f -n 100 logs/log*
