#!/bin/bash
#
# Check the availability of a server with ping 
# and monitor state changes (server got offline or online)
# in a log file
#
# 3/13/2013 framp at linux-tips-and-tricks dot de
#

IP="192.168.0.1"		# ip to ping
SLEEP=1m			# check interval in minutes
LOG_FILE="checkServerAvailability.log"

exec 1> >(tee -a $LOG_FILE >&1)

trap 'cleanup' SIGINT SIGPIPE SIGTERM

function cleanup() {
	echo "Stopping ping check at $(date)"
	exit
}

unavail=0

echo "Starting ping check at $(date)"

:	$(ping -W 3 -c 3 $IP)
	rc=$?
	if ((! $rc)); then
		echo "$IP available at $(date)"
	else
		echo "$IP UNavailable at $(date)"
	fi

while ((1)); do

:	$(ping -W 3 -c 3 $IP)
	rc=$?
	if (( ! $rc)); then
		if ((unavail)); then
			unavail=0
			echo "$IP now available at $(date)"
		fi
	else
		if ((! unavail)); then
			unavail=1
			echo "$IP now UNavailable at $(date)"
		fi
	fi
	sleep $SLEEP
done
