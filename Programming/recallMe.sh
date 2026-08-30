#!/bin/bash

#
#	Proof of concept code which passes bash invocation parameters to itself
#	when calling itself in a loop.
#
#	This is required if a bash script checks whether there is a more current
#	script version available and replaces the current running script with the
#	latest version and executes the updated script with the same invocation
#	parameters. 
#
#	Example:
#	recallMe.sh 3 -t -h -f 1 -T "4 7 1 1" 
#
#	The script update will happen transparently for the script caller
#
#	(C) 2016 - framp at linux-tips-and-tricks dot de
#

MYSELF=${0##*/}
MYNAME=${MYSELF%.*}
SCRIPT_DIR=$( cd $( dirname ${BASH_SOURCE[0]}); pwd | xargs readlink -f)

DEBUG=0			# set to 1 for some debug outputs

if [[ $# < 1 ]]; then
	echo -e "Call me with any parameters including strings with spaces.\nFirst parameter defines the recall count"
	exit
fi

RECALL_CNT=$1

if [[ ! $RECALL_CNT =~ [2-9] ]]; then
	echo "First parameter has to be 2-9"
	exit
fi

[[ $RESTART == "" ]] && RESTART=0

echo "Hello: I'm $MYNAME and restarted $RESTART times with $@"

# save parameters $1 to $n in an array and keep spaces in parameters

parameters=()
for (( i=1; i<=$#; i++ )); do
	p=${!i}
	(( $DEBUG )) && echo "Saving parameter $i: >$p<"
	parameters+=("$p")
done

(( $DEBUG )) && echo "@: $@"
(( $DEBUG )) && echo "Saved parameters: ${parameters[@]}"

# Now check whether there is a new version available e.g.
# --- wget <http://myDomain/myVersionInfo.txt> -q --tries=3 --timeout=3 -O "$MYNAME.$$"
# and if newer version is available replace script with never version e.g.
# --- wget <http://myDomain/$MYSELF> -q --tries=3 --timeout=3 -O "$SCRIPT_DIR/$MYSELF"

# now recall updated script with same parameters or terminate proof of concept recall loop

r=$RESTART
if [[ $r == $RECALL_CNT ]]; then
	echo "Hello: I'm $MYNAME and terminate after restarted $RESTART times with $@"
	export RESTART=
	exit
else
	(( r++ ))
	export RESTART=$r
	echo "Hello: I'm $MYNAME restarting $RESTART with ${parameters[@]}"
	exec "$(which bash)" --noprofile "$0" "${parameters[@]}"		# no return
fi
