#!/bin/bash

#  Detect maximum possible MTU for client 

#  10/12/03 - framp at linux-tips-and-tricks dot de

   DFDetected=0
   testMTU=1600

   echo "Calculating optimal MTU"
   echo "Decreasing MTU until fragmentation starts..." 
   while [[ $DFDetected -eq 0 ]]; do
      dummy=`ping -c1 195.135.220.3 -s $testMTU -M do | grep "DF set"`
      DFDetected=$?
      if [[ $DFDetected -eq 0 ]]; then
         let testMTU=$testMTU-100
      fi
   done

   DFDetected=0
   let testMTU=$testMTU+100

   while [[ $DFDetected -eq 0 ]]; do
      dummy=`ping -c1 195.135.220.3 -s $testMTU -M do | grep "DF set"`
      DFDetected=$?
      if [[ $DFDetected -eq 0 ]]; then
         let testMTU=$testMTU-10
      fi
   done

   DFDetected=0
   let testMTU=$testMTU+10

   echo "Increasing MTU until fragmentation stops..." 
   while [[ $DFDetected -eq 0 ]]; do
      dummy=`ping -c1 195.135.220.3 -s $testMTU -M do | grep "DF set"`
      DFDetected=$?
      if [[ $DFDetected -eq 0 ]]; then
         let testMTU=$testMTU-2
      fi
   done

   let mtuRequired=$testMTU+28
   echo "Adding IP header of 28 bytes to MTU..."
   echo "Optimal MTU is $mtuRequired" 

   defaultGatewayNic=`route -n | awk '/^[0]+\.[0]+\.[0]+\.[0]+/ { print $NF; } '`
   mtuActive=`ifconfig $defaultGatewayNic | perl -n -e '{ if ($_=~/MTU:(\d+)/) { print "$1"}; }'`

   echo "MTU of $mtuActive is used on interface $defaultGatewayNic"

   if [[ $mtuActive -gt $mtuRequired ]]; then
      echo "Current MTU should be corrected to $mtuRequired"
   else
      echo "MTU is Ok"
   fi
 
