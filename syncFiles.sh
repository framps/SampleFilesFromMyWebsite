#!/bin/bash

#
# Kleines Shellscript um Dateien in zwei Verzeichnissen zu syncen
# Dabei können die Dateien im Zielverzeichnis gelöscht werden. Das
# Script merkt sich, welche Dateien kopiert wurden und synced die
# schon kopierten Dateien nicht mehr mit --exclude-from bei rsync.
#
# 14.3.2010 framp@linux-tips-and-tricks.de
#

function cleanup() {
   IFS=$SAVE_IFS                             # separator wieder in alten zustand setzen
}

trap 'cleanup' SIGHUP SIGINT SIGPIPE SIGTERM # rufe cleanup wenn script abbricht

MYSELF="${0##*/}"										# hole den scriptnamen
SYNCED_FILES="$MYSELF.exclude"					# dateinname wo die gesyncten files gemerkt werden

SOURCE="test/source"									# default quelle
DESTINATION="test/target"							# default ziel

if [ $# == 2 ]; then									# 2 parameter mitgegeben
	SOURCE=$1											# erster parameter ist quelle directory
	DESTINATION=$2										# zweiter parameter ist ziel directory
fi

if [ -e $SYNCED_FILES ]; then            		# falls datei mit den gesyncten files existiert
	EXCLUDE="--exclude-from=$SYNCED_FILES"		# baue exclude parameter für rsync
fi

if [ ! -e $SOURCE ]; then							# prüfe on quellverzeichnis existiert
	echo "??? $SOURCE existiert nicht"
	exit 1
fi

if [ ! -e $TARGET ]; then							# prüfe ob zielverzeichnis existiert
	echo "??? $SOURCE existiert nicht"
	exit 1
fi

FILES=$(rsync -rav $SOURCE $DESTINATION $EXCLUDE)	# sync u.U. mit exclude

find $DESTINATION -depth -type d -empty -exec rmdir {} \;	# lösche alle leeren directories

SAVE_IFS=$IFS                                # sicher alten bash sparator (ist space)
IFS=$(echo -en "\n\b")                       # setze separator zu newline oder backspace

I=0
LAST=0
for file in $FILES; do								# zaehle wieviele einträge
	let LAST=LAST+1
done

let LAST=LAST-2										

for file in $FILES; do								# bearbeite alle files
	let I=$I+1
	if [[ $I -eq 1 || $I -gt $LAST ]]; then	# erste und die beiden letzten zeilen ignorieren
		continue
	fi
	
	let length=${#file}-1							# letzte stelle des filenamens
	if [[ ${file:$length} != "/" ]]; then		# keine directories excluden (die enden mit /)
		echo "Synced $file"							# meldung welche files gesynced wurde
		echo $file >> $SYNCED_FILES				# exclude das file
	fi			
done

cleanup
