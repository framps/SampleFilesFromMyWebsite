#
# Tiny Networkinterface Monitor (tnm)
#
# Summary:
#   Short script which collects network interface usage informations for DSL interfaces.
#   Useful to get a quick overview about the interface usage over time. 
#   There exist two output formats: The first one displays the throughput weigthed with the maximum receive and transmit
#   speed. The second one does not weighting. 
#
# Parameters:
#   No parameter (default): Display the throughput weighted with the maximum receive and transmit speed
#   Any other parameter: Display the throughput not weighted
#
# Script has to be customized. See customization section below for details.
#
# Author: framp at linux-tips-and-tricks dot de
#
# Feel free to extend this script. But please let me know about any useful extensions or improvements.
#
# History: 
#	??/??/?? - Initial version
# 	11/04/06 - V 0.1 - Screen size not fixed any more
#	07/30/09 - V 0.2 - Check for configuration done
#     12/04/11 - V 0.3 - Major rewrite and improvement (thx TheAnimal)
#
# The latest actual version can be downloaded from http://www.linux-tips-and-tricks.de

MYSELF=`basename $0`
VERSION="0.3"

#set -o xtrace
#set -o verbose

# ======================> ###### start customization section
iv=1									# <-------------- sleep interval in seconds (e.g. 1 second)
measureUnit=							# <-------------- transfer speed unit of interface per second (Kb, KB, Mb, MB)
displayUnit=							# <-------------- unit to display the load on the interface (e.g. Mb)
let trxSpeed=		  					# <-------------- transmit speed in units (e.g 100)
let rcvSpeed=  							# <-------------- receive speed in units (e.gg 100)
if=	  								# <-------------- interface to measure throughput (e.g. eth0)
width=80								# <-------------- width of display in characters (e.g. 80)
# ======================> ###### end Customization section

if [[ $if == "" ]]; then
	echo "??? $MYSELF not customized. Please edit the customization section in $MYSELF first"
	exit 1
fi

measureUnitFactor=0
case $measureUnit in
	Kb) measureUnitFactor=1024;;
	Mb) measureUnitFactor=1048576;;
	KB) measureUnitFactor=$((1024*8));;
	MB) measureUnitFactor=$((1048576*8));;
esac

if [[ $measureUnitFactor -eq 0 ]]; then
	echo "??? $MYSELF not customized. Please edit the customization section in $MYSELF for measureUnit"
	exit 1
fi

displayUnitFactor=0
case $displayUnit in
	Kb) displayUnitFactor=1024;;
	Mb) displayUnitFactor=1048576;;
	KB) displayUnitFactor=$((1024*8));;
	MB) displayUnitFactor=$((1048576*8));;
esac

if [[ $displayUnitFactor -eq 0 ]]; then
	echo "??? $MYSELF not customized. Please edit the customization section in $MYSELF for displayUnit"
	exit 1
fi

# bandwidth in bytes per interval (usually b/s)
let trxBandwidth=trxSpeed*$measureUnitFactor*$iv 	
let rcvBandwidth=rcvSpeed*$measureUnitFactor*$iv		
let sumBandwidth=$trxBandwidth+$rcvBandwidth

last_tx=0		# last trx byte count 
last_rx=0		# last rcv byte count 
started=0		# initialization flag

headerInsertion=20
headerCount=$headerInsertion

if [[ $1 == "" ]]; then
	equal=0
else
	equal=1
fi

padNull="                         "             
trxChar="TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT"
rcvChar="RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR"
dashChar="------------------------------------------------------------------------------------------------------------------------"
spaceChar="                                                                                                                       "
headerLeft=" ${displayUnit}s   %"
headerRight="  %  ${displayUnit}s"

let width=$width-${#headerLeft}-${#headerRight}

if [[ $equal -eq 1 ]]; then
	let trxWidthSum=$width/2
	let rcvWidthSum=$width/2
else
   	let trxWidthSum=$trxBandwidth*100/$sumBandwidth*$width/100
	let rcvWidthSum=$rcvBandwidth*100/$sumBandwidth*$width/100
fi

let dashRightLength=$trxWidthSum
let dashLeftLength=$rcvWidthSum
dashRight=${dashChar:0:$dashRightLength} 
dashLeft=${dashChar:0:$dashLeftLength}
header="$headerLeft ${dashLeft}+${dashRight} $headerRight"

while [[ 1 ]]; do
   ut_start=$ut_end
   ut_end=$(</proc/uptime); ut_end=${ut_end//./}; ut_end=${ut_end// */}; 
   p=$(cat /proc/net/dev | grep $if)

   new_tx=$(echo $p | awk ' { print $10}')
   new_rx=$(echo $p | awk ' { print $2}')

#  for simulation
#   new_tx=$(($last_tx+($trxSpeed*$measureUnitFactor)/2))
#   new_rx=$(($last_rx+($rcvSpeed*$measureUnitFactor)/2))

   let new_rx=$new_rx
   let new_tx=$new_tx

   if [[ $started == 0 ]]; then
      last_tx=$new_tx
      last_rx=$new_rx
      started=1
   else
      let interval=$ut_end-$ut_start

      let t=($new_tx-$last_tx)/$displayUnitFactor*100/$interval
      let trxPerc=$t*$trxBandwidth/$displayUnitFactor/100
      last_tx=$new_tx

      let r=($new_rx-$last_rx)/$displayUnitFactor*100/$interval
      let rcvPerc=$r*$rcvBandwidth/$displayUnitFactor/100
      last_rx=$new_rx

      if [[ $trxPerc -gt 100 ]]; then
         trxPerc=100
      fi
      if [[ $rcvPerc -gt 100 ]]; then
         rcvPerc=100
      fi
      let trxWidth=$trxPerc*$trxWidthSum/100
      let rcvWidth=$rcvPerc*$rcvWidthSum/100
      trx=${trxChar:0:$trxWidth}
      rcv=${rcvChar:0:$rcvWidth}
      let rest=$trxWidthSum-$trxWidth
      if [[ $rest < 0 ]]; then
         rest=0
      fi
      spct=${spaceChar:0:$rest}
      let rest=$rcvWidthSum-$rcvWidth
      if [[ $rest < 0 ]]; then
         rest=0
      fi
      spcr=${spaceChar:0:$rest}

	if [[ $t -gt 1024 ]]; then
	   t="****"
	fi
      let l=4-${#t}
      t=${padNull:0:$l}${t}      

	if [[ $r -gt 1024 ]]; then
	   r="****"
	fi
      let l=4-${#r}
      r=${padNull:0:$l}${r}     
 
      let l=3-${#trxPerc}
      trxPerc=${padNull:0:$l}${trxPerc}     
      let l=3-${#rcvPerc}
      rcvPerc=${padNull:0:$l}${rcvPerc}    

      let headerCount=${headerCount}+1
      if [[ $headerCount -gt $headerInsertion ]]; then
         echo "$header"
         headerCount=0
      fi
      echo "${r}" "${rcvPerc}" ${rcv}"${spcr}""|""${spct}"${trx} "${trxPerc}" "${t}"
   fi

   sleep $iv
done
