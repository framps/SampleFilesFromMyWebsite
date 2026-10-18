#
# shut down system if there is no system active
#
# Function:
# ---------
# Check whether there are still systems specified with their IP or DNS name powered on
# If somebody is logged on to the system the system is not shut down
# Between 1 AM and 3 AM the system is shutdown unconditionally
#
# Installation
# -------------
# - Copy script into /usr/local/sbin and chmod +x of file as root
# - insert following 2 lines without the leading # as root in /etc/crontab
#      # Check every 5 minutes whether system can be shut down
#      -0-59/5 * * * *   root  /usr/local/sbin/ishutdown
#
# Customization
# -------------
# - Edit variable CHECK_IPS to contain the IPs of the systems to monitor
#
# 03/17/09 framp www.linux-tips-and-tricks.de

#set -o xtrace

# number of script invocations until system is shut down
SHUTDOWN_DELAY=3		# invocations (cron set to 5 mins => system shut down after 15 mins of system inactivity)
########################################################
#
# EDIT FOLLOWING LINE starting with CHECK_IPS
#
########################################################
CHECK_IPS="192.168.0.2 192.168.0.4 192.168.0.6 192.168.0.104"

r=`who -u`
# if somebody logged on then don't shut down
if [[ $r != "" ]]; then
   exit 0;
fi

t=`date +%H`	# hour

# shut down system in any case between 1 and 3 am (just in case a system wasn't powered off)
if [ $t -ge "1" -a $t -lt "3" ]; then
        logger -t ishutdown "Too late"
        logger -t ishutdown "System shut down."
	echo "shutdown -h now"
	shutdown -h now
	exit 0
fi

aliveIPs=`fping -a $CHECK_IPS 2>/dev/nul`

if [[ $aliveIPs == "" ]]; then
# wait for some time until the system is shut down without a user online/system started
	if [[ ! -e /tmp/shutdownDelay ]]; then
	   echo $SHUTDOWN_DELAY > /tmp/shutdownDelay
              logger -t ishutdown "Initializing counter to $SHUTDOWN_DELAY."
        else
	   t=`cat /tmp/shutdownDelay`
           let t=$t-1
	   if [[ $t -gt 0 ]]; then
              echo $t > /tmp/shutdownDelay
              logger -t ishutdown "Counter now $t"
           else
              logger -t ishutdown "Counter now $t"
              logger -t ishutdown "System shut down."
              shutdown -h now
#	      echo "shutdown -h now"
	      rm /tmp/shutdownDelay
           fi
	fi
else
	rm /tmp/shutdownDelay 2>/dev/nul
fi


