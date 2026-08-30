#!/bin/bash
 
### BEGIN INIT INFO
# Provides:          seafile
# Required-Start:    $local_fs $remote_fs $network
# Required-Stop:     $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Starts Seafile and Seahub
# Description:       starts Seafile and Seahub
### END INIT INFO
# 12/30/14 - framp at linux-tips-and-tricks dot de 
#### CONFIG START ####
user=seafile
seafile_dir=/home/seafile/mycloud
##### CONFIG END #####
 
script_path=${seafile_dir}/seafile-server-latest
pid_path=${seafile_dir}/pids

SUDO="sudo -u ${user}"

if ls -la /home/seafile/mycloud/seafile-server-latest | egrep "\-([[:digit:]])+" | grep -q 4; then
	read -a TASKS <<< "ccnet seafdav seaf-server"
else
	read -a TASKS <<< "ccnet fileserver seafdav seaf-server"
fi

function checkTaskActive() { # name
        if [ -e $pid_path/$1.pid ]; then
                pid=$(cat $pid_path/$1.pid)
                if [ $(ps -p $pid | wc -l) -eq 2 ]; then
                        return 0 
                fi
        fi      
        return 1 
} 
# Change the value of fastcgi to true if fastcgi is to be used
fastcgi=true
# Set the port of fastcgi, default is 8000. Change it if you need different.
fastcgi_port=8000

[ $fastcgi = true ] && FASTCGI="-fastcgi" || FASTCGI=""
 
case "$1" in
        start)
                $SUDO ${script_path}/seafile.sh $1 
                $SUDO ${script_path}/seahub.sh $1$FASTCGI ${fastcgi_port} 
        ;;
        restart)
                $SUDO ${script_path}/seafile.sh $1 
                $SUDO ${script_path}/seahub.sh $1$FASTCGI ${fastcgi_port} 
        ;;
        stop)
                $SUDO ${script_path}/seafile.sh $1 
                $SUDO ${script_path}/seahub.sh $1 
        ;;
	status)
		nr=0
		tasks=""
		for task in ${TASKS[@]}; do
			if $(checkTaskActive $task); then
				(( nr++ ))
			else
				tasks="$tasks $task"
			fi
		done

		if [[ "$nr" -eq "${#TASKS[@]}" ]]; then
			echo "seafile is running"
		else
			echo "seafile not running"
			if [[ "$nr" -ne 0 ]]; then
				echo "Missing:$tasks"
			fi
		fi	
	;;
        *)
                echo "Usage: /etc/init.d/seafile {start|stop|restart|status}"
                exit 1
        ;;
esac
