#!/bin/bash
#
# Calculates a finbonacci number with a double recursive bash script
#
# www dot linux-tips-and-tricks dot de

function fn() {
	local fm1
	local fm2
	local result
	if [[ $1 -le "1" ]]; then
		echo "1"
	else
		let fm1=$1-1
		let fm2=$1-2
		fm1=`fn $fm1`
		fm2=`fn $fm2`
		let result=$fm1+$fm2
		echo $result
	fi


}

result=`fn $1`

echo "Fibonacci number of $1 is $result"
