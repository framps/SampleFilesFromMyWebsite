#!/bin/bash
#
# Small script which detects all active systems in a local network and queries the DNS names of the IPs 
#
# (C) 2013 framp at linux-tips-and-tricks dot de
#
for prog in "fping host"; do
	if ! which $prog 1>/dev/null 2>&1; then
		echo "Missing $prog -> sudo apt-get install $prog"
		exit 1 
	fi
done
if (( $# < 2 )); then
	echo "Missing first ip and last ip of subnet (e.g. 192.168.0.0 and 192.168.0.255) as parameter"
	exit 1 
fi
echo "Resolving DNS names of all IPs between $1 and $2 (Will take some time) ..."
for ip in $(fping -aq -g $1 $2 2>/dev/null); do
	dnsname=$(echo $(host $ip) | cut -f5 -d' ' | sed 's/.$//') 
	echo "$ip - $dnsname"
done
