#!/bin/bash
#
# Calculates a factorial number on an iterative way and recursive way
#
# www dot linux-tips-and-tricks dot de

function fak_r() {
	local fm1
	local result
	if [[ $1 -le "1" ]]; then
		echo "1"
	else
		let fm1=$1-1
		fm1=`fak_r $fm1`
		let result=$1*$fm1
		echo $result
	fi
}

function fak_i() {
	local result=1
	for ((i=2; i<=$1; i++)); do
		let result=$result*$i
	done
	echo $result
}

echo "Recursive factorials:"
for ((f=1;f<=10;f++)); do
	result=`fak_r $f`
	echo -n "$f:$result "
done

echo
echo "Iterative factorials:"
for ((f=1;f<=10;f++)); do
	result=`fak_i $f`
	echo -n "$f:$result "
done
echo

