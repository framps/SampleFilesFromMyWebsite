#
# Sample script to enable/disable ports on a linux router for local game clients
#
# WARNING: Customize this sample carefully! You might damage your firewall by accident!
#
# 2005/12 framp 
#

SUDO=/usr/bin/sudo

# customize the following parms according your environment

IF="eth0"		# external interface
LF="eth0"		# internal interface
IP="192.168.0.2"	# internal IP

#set -o xtrace		# to enable tracing

# run as root - needs sudo definitions

if test -x $SUDO ; then
   if test $UID -ne 0; then
	exec $SUDO $0 $*
   fi
fi

me=`basename $0`

if [[ $1 == "" ]]; then
	echo "$me: Missing -I (insert) or -D (delete)"
	exit 1;
fi

if [[ $1 == "-I" ]]; then
	cmd="-I"
	action="Enabling games..."
else
	cmd="-D"
	action="Disabling games..."
fi
 
logger "$me: $action"

AWK=`which awk`
SED=`which sed`
IFCONFIG="/sbin/ifconfig"
EXTIP="`$IFCONFIG $IF 2>/dev/null|$AWK '/inet addr:/ {print $2}'|$SED 's/addr://'`"

if [[ $EXTIP == "" ]]; then
	echo "$me: Error retrieving external IP address from interface $IF"
	exit 1
fi

# enable masquerading
/usr/sbin/iptables -t nat $cmd POSTROUTING -o $IF -s $IP -j MASQUERADE

#gilde server
echo "Gilde Server"
/usr/sbin/iptables -t nat $cmd PREROUTING -p tcp -d $EXTIP --dport 7531 -j DNAT --to $IP
/usr/sbin/iptables -t nat $cmd PREROUTING -p udp -d $EXTIP --dport 7531 -j DNAT --to $IP
/usr/sbin/iptables $cmd FORWARD -p tcp -o $IF -i $LF -s $IP --sport 7531 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p tcp -i $IF -o $LF -d $IP --dport 7531 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p udp -o $IF -i $LF -s $IP --sport 7531 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p udp -i $IF -o $LF -d $IP --dport 7531 -j ACCEPT

# age of empires server
echo "Age of empires server"
/usr/sbin/iptables -t nat $cmd PREROUTING -p udp -d $EXTIP --dport 2300:2400 -j DNAT --to $IP
/usr/sbin/iptables -t nat $cmd PREROUTING -p tcp -d $EXTIP --dport 2300:2400 -j DNAT --to $IP
/usr/sbin/iptables -t nat $cmd PREROUTING -p udp -d $EXTIP --dport 47624 -j DNAT --to $IP
/usr/sbin/iptables -t nat $cmd PREROUTING -p tcp -d $EXTIP --dport 47624 -j DNAT --to $IP
/usr/sbin/iptables $cmd FORWARD -p tcp -i $IF -o $LF -d $IP --dport 2300:2400 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p udp -i $IF -o $LF -d $IP --dport 2300:2400 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p tcp -i $LF -o $IF -s $IP --sport 2300:2400 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p udp -i $LF -o $IF -s $IP --sport 2300:2400 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p udp -i $IF -o $LF -d $IP --dport 47624 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p tcp -i $IF -o $LF -d $IP --dport 47624 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p udp -i $LF -o $IF -s $IP --sport 47624 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p tcp -i $LF -o $IF -s $IP --sport 47624 -j ACCEPT

# habohotel
echo "Hobotel"
/usr/sbin/iptables $cmd FORWARD -p tcp -i $LF -o $IF -s $IP --dport 37005 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p tcp -i $IF -o $LF -d $IP --sport 37005 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p tcp -i $LF -o $IF -s $IP --dport 37300:37500 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p tcp -i $IF -o $LF -d $IP --sport 37300:37500 -j ACCEPT

#
# irc
#
echo "IRC"
/usr/sbin/iptables $cmd FORWARD -p tcp -o $IF -i $LF -d 0/0 -s $IP --dport 6667:6668 -j ACCEPT

#
# icq
#
echo "ICQ"
/usr/sbin/iptables $cmd FORWARD -p tcp -o $IF -i $LF -d 0/0 -s $IP --dport 5190 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p tcp -i $IF -o $LF -s 0/0 -d $IP --sport 5190 -j ACCEPT

# mediaplaetr
echo "Mediaplayer"
/usr/sbin/iptables $cmd FORWARD -p tcp -o $IF -i $LF -d 0/0 -s $IP --dport 1755 -j ACCEPT
/usr/sbin/iptables $cmd FORWARD -p tcp -i $IF -o $LF -s 0/0 -d $IP --sport 1755 -j ACCEPT

echo "$me: Done"
