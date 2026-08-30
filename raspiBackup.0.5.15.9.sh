#!/bin/bash
# vim: set expandtab tabstop=8 shiftwidth=8 autoindent smartindent
#
# Short script to create and restore a backup of raspbian or raspbmc
#
# Invoke the script with -h to get a list of all possible arguments.
# Default parameters are defined in the script itself and can be customized.
#
# Script should be named raspiBackup.sh and copied into /usr/local/bin 
# to call it with cron every Sunday at 10 pm
#
# Samples in crontab:
# 00 22  * * 0 /usr/local/bin/raspiBackup.sh -p /backup -t xbmc -k 5 -o 'service xbmc stop' -a 'service xbmc start'
# 00 22  * * 0 /usr/local/bin/raspiBackup.sh -p /backup -t rsync -k 5 -o 'service xbmc stop' -a 'service xbmc start' / -e foor@bar.com
# 00 22  * * 0 /usr/local/bin/raspiBackup.sh -p /backup -t tar -k 5 -o 'service xbmc stop' -a 'service xbmc start'
# 00 22  * * 0 /usr/local/bin/raspiBackup.sh -p /backup -t dd -k 5 -e foor@bar.com
#
# !!! Check the created backup from time to time whether you can restore a system.
# !!! If you need the backup and it doesn't contain the data you expect that's not nice.
#
# See http://www.linux-tips-and-tricks.de/raspiBackup for latest code and additional information 
#
# (C) 2013,2015 - framp at linux-tips-and-tricks dot de
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#######################################################################################################################
#
# Kleines Script um ein Backup eines raspbians oder raspbmc zu erstellen
#
# Mögliche Parameter werden beim Aufruf des Scripts mit -h angezeigt.
# Falls Parameter nicht beim Aufruf mitgegeben werden benutzt das Script
# Standardwerte, die im folgenden definiert und geändert werden können.
#
# Das Script sollte raspiBackup.sh heissen, in /usr/local/bin kopiert werden
# und am besten per cron regelmäßig aufgerufen werden. Z.B jeden Sonntag um 22 Uhr.
#
# Beispielzeile dafür in der crontab:
# 00 22  * * 0 /usr/local/bin/raspiBackup.sh -p /backup -t xbmc -k 5 -o 'service xbmc stop' -a 'service xbmc start'
# 00 22  * * 0 /usr/local/bin/raspiBackup.sh -p /backup -t rsync -k 5 -o 'service xbmc stop' -a 'service xbmc start' -e foor@bar.com
# 00 22  * * 0 /usr/local/bin/raspiBackup.sh -p /backup -t tar -k 5 -o 'service xbmc stop' -a 'service xbmc start'
# 00 22  * * 0 /usr/local/bin/raspiBackup.sh -p /backup -t dd -k 5 -e foor@bar.com
#
# !!! Das erstellte Backup sollte immer regelmäßig geprüft werden ob es funktioniert ein System zu restaurieren. 
# !!! Es ist sehr schlecht wenn man in dem Moment, wo man das Backup benötigt, feststellt, dass das Backup untauglich ist.
#
# Auf http://www.linux-tips-and-tricks.de/raspiBackup steht der aktuelle Code bereit sowie weitere Informationen
#
# (C) 2013,2015 framp at linux-tips-and-tricks dot de
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#######################################################################################################################

VERSION="0.5.15.9" # don't change the version layout, used to grep the version for updatecheck

MYSELF=${0##*/}
MYNAME=${MYSELF%.*}

if [ ! -n "$BASH" ] ;then
        echo "??? ERROR: Unable to execute script. bash interpreter missing."
        echo "??? DEBUG: $(lsof -a -p $$ -d txt | tail -n 1)"
        exit 127
fi

# add pathes if not already set (usually not set in crontab)

if [[ -e /bin/egrep ]]; then
	PATHES="/bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin"
	for p in $PATHES; do
		if ! echo $PATH | /bin/egrep "^$p|:$p" 2>&1 1>/dev/null; then
			[[ -z $PATH ]] && export PATH=$p || export PATH="$p:$PATH"
		fi
	done
fi

DATE=$(date +%Y%m%d-%H%M%S)
HOSTNAME=$(hostname) 
NL=$'\n'

# hosts which will get the updated backup script with parm -y  

DEPLOYMENT_HOSTS="root@raspifix root@raspberrypi root@raspiap root@raspibmc pi@seafile"

GIT_DATE="$Date: 2015-10-31 10:40:26 +0100$"
GIT_DATE_ONLY=${GIT_DATE/: /}
GIT_DATE_ONLY=$(echo $GIT_DATE | cut -f 2 -d ' ')
GIT_TIME_ONLY=$(echo $GIT_DATE | cut -f 3 -d ' ') 
GIT_COMMIT="$Sha1: 40f9f7f3dd1b62457ed0f5392145ab74b7191333$"
GIT_COMMIT_ONLY=$(echo $GIT_COMMIT | cut -f 2 -d ' ' | sed 's/\$//')

GIT_CODEVERSION="$MYSELF $VERSION, $GIT_DATE_ONLY/$GIT_TIME_ONLY - $GIT_COMMIT_ONLY"

DOWNLOAD_URL="http://www.linux-tips-and-tricks.de/raspiBackup.sh"
VERSION_CHECK_URL="http://www.linux-tips-and-tricks.de/raspiBackup.version"

LOG_NONE=0
LOG_DEBUG=1
declare -A LOG_LEVELs=( [$LOG_NONE]="Off" [$LOG_DEBUG]="Debug" )
POSSIBLE_LOG_LEVELs=""
for K in "${!LOG_LEVELs[@]}"; do
	[[ -z $POSSIBLE_LOG_LEVELs ]] && POSSIBLE_LOG_LEVELs="$K=${LOG_LEVELs[$K]}" || POSSIBLE_LOG_LEVELs="$POSSIBLE_LOG_LEVELs | $K=${LOG_LEVELs[$K]}"
done

MSG_LEVEL_MINIMAL=0
MSG_LEVEL_DETAILED=1
declare -A MSG_LEVELs=( [$MSG_LEVEL_MINIMAL]="Minimal" [$MSG_LEVEL_DETAILED]="Detailed")
POSSIBLE_MSG_LEVELs=""
for K in "${!MSG_LEVELs[@]}"; do
	[[ -z $POSSIBLE_MSG_LEVELs ]] && POSSIBLE_MSG_LEVELs="$K=${MSG_LEVELs[$K]}" || POSSIBLE_MSG_LEVELs="$POSSIBLE_MSG_LEVELs | $K=${MSG_LEVELs[$K]}"
done

LOG_OUTPUT_SYSLOG=0
LOG_OUTPUT_VARLOG=1			
LOG_OUTPUT_BACKUPLOC=2
LOG_OUTPUT_HOME=3
declare -A LOG_OUTPUT_LOCs=( [$LOG_OUTPUT_SYSLOG]="/var/log/syslog" [$LOG_OUTPUT_VARLOG]="/var/log/raspiBackup/<hostname>.log" [$LOG_OUTPUT_BACKUPLOC]="<backupPath>" [$LOG_OUTPUT_HOME]="raspiBackup.log")
POSSIBLE_LOG_LOCs=""
for K in "${!LOG_OUTPUT_LOCs[@]}"; do
	[[ -z $POSSIBLE_LOG_LOCs ]] && POSSIBLE_LOG_LOCs="$K=${LOG_OUTPUT_LOCs[$K]}" || POSSIBLE_LOG_LOCs="$POSSIBLE_LOG_LOCs | $K=${LOG_OUTPUT_LOCs[$K]}"
done

LOG_TYPE_MSG=0
LOG_TYPE_DEBUG=1
declare -A LOG_TYPEs=( [$LOG_TYPE_MSG]="MSG" [$LOG_TYPE_DEBUG]="DBG")

BACKUPTYPE_DD="dd"
BACKUPTYPE_DDZ="ddz"
BACKUPTYPE_TAR="tar"
BACKUPTYPE_TGZ="tgz"
BACKUPTYPE_RSYNC="rsync"
BACKUPTYPE_XBMC="xbmc"
declare -A FILE_EXTENSION=( [$BACKUPTYPE_DD]=".img" [$BACKUPTYPE_DDZ]=".img.gz" [$BACKUPTYPE_RSYNC]="" [$BACKUPTYPE_TGZ]=".tgz" [$BACKUPTYPE_TAR]=".tar" [$BACKUPTYPE_XBMC]=".tgz")
# map dd/tar to ddz/tgz extension if -z switch is used
declare -A Z_TYPE_MAPPING=( [$BACKUPTYPE_DD]=$BACKUPTYPE_DDZ [$BACKUPTYPE_TAR]=$BACKUPTYPE_TGZ )

readarray -t SORTED < <(for a in "${!FILE_EXTENSION[@]}"; do echo "$a"; done | sort)
ALLOWED_TYPES=""
POSSIBLE_TYPES=""
for K in "${SORTED[@]}"; do
	[[ -z $POSSIBLE_TYPES ]] && POSSIBLE_TYPES=$K || POSSIBLE_TYPES="$POSSIBLE_TYPES|$K"
	lastChar="${K: -1}"
	if [[ $lastChar == "z" ]]; then         # skip tgz and ddz as allowed types, now handled with -z invocation parameter, still accept old types for backward compatibility
		continue
	fi
	[[ -z $ALLOWED_TYPES ]] && ALLOWED_TYPES=$K || ALLOWED_TYPES="$ALLOWED_TYPES|$K"
done

PRE_BACKUP_EXTENSION="pre"
POST_BACKUP_EXTENSION="post"

tty -s
INTERACTIVE=!$?

#################################################################################
#
# --- Messages in English and German
#
# (volunteers to translate the messages into other languages are welcome)
#
#################################################################################

# supported languages

MSG_EN=1      # english	(default)
MSG_DE=1      # german

declare -A MSG_EN
declare -A MSG_DE

MSG_UNDEFINED=0
MSG_EN[$MSG_UNDEFINED]="??? RBK0000E: Undefined message. Pls inform the author %1"
MSG_DE[$MSG_UNDEFINED]="??? RBK0000E: Unbekannte Meldung. Bitte den Author %1 informieren"
MSG_ASSERTION_FAILED=1
MSG_EN[$MSG_ASSERTION_FAILED]="??? RBK0001E: Assertion failed in line %1"
MSG_DE[$MSG_ASSERTION_FAILED]="??? RBK0001E: Zusicherungsfehler in Zeile %1"
MSG_RUNASROOT=2
MSG_EN[$MSG_RUNASROOT]="??? RBK0002E: Script has to be run as root. Use 'sudo %1 %2'"
MSG_DE[$MSG_RUNASROOT]="??? RBK0002E: Script muss als root gestartet werden. Benutze 'sudo %1 %2'"
MSG_MISSING_OPTIONS=3
MSG_EN[$MSG_MISSING_OPTIONS]="??? RBK0003E: Missing option %1"
MSG_DE[$MSG_MISSING_OPTIONS]="??? RBK0003E: Option %1 fehlt"
MSG_UNKONWN_EMAIL_PROG=4
MSG_EN[$MSG_UNKONWN_EMAIL_PROG]="??? RBK0004E: Unknown email programm %1"
MSG_DE[$MSG_UNKONWN_EMAIL_PROG]="??? RBK0004E: Unbekanntes email Programm %1"
MSG_BACKUP_FAILED=5
MSG_EN[$MSG_BACKUP_FAILED]="??? RBK0005E: Backup failed in task %1 with RC %2. See logfile %3 for details"
MSG_DE[$MSG_BACKUP_FAILED]="??? RBK0005E: Backup fehlerhaft in Schritt %1 mit RC %2 beendet. Weitere Informationen finden sich im Logfile %3"
MSG_INVALID_BACKUPTYPE=6
MSG_EN[$MSG_INVALID_BACKUPTYPE]="??? RBK0006E: Invalid backuptype %1"
MSG_DE[$MSG_INVALID_BACKUPTYPE]="??? RBK0006E: Unbekannter Backuptyp %1"
MSG_STARTING_SERVICES=7
MSG_EN[$MSG_STARTING_SERVICES]="--- RBK0007I: Starting services: '%1'"
MSG_DE[$MSG_STARTING_SERVICES]="--- RBK0007I: Services werden gestartet: '%1'"
MSG_STOPPING_SERVICES=8
MSG_EN[$MSG_STOPPING_SERVICES]="--- RBK0008I: Stopping services: '%1'"
MSG_DE[$MSG_STOPPING_SERVICES]="--- RBK0008I: Services werden gestoppt: '%1'"
MSG_STARTED=9
MSG_EN[$MSG_STARTED]="--- RBK0009I: %1: %2 V%3 started at %4"
MSG_DE[$MSG_STARTED]="--- RBK0009I: %1: %2 V%3 um %4 gestartet"
MSG_STOPPED=10
MSG_EN[$MSG_STOPPED]="--- RBK0010I: %1: %2 V%3 stopped at %4"
MSG_DE[$MSG_STOPPED]="--- RBK0010I: %1: %2 V%3 um %4 beendet"
MSG_NO_BOOT_PARTITION=11
MSG_EN[$MSG_NO_BOOT_PARTITION]="??? RBK0011E: No boot partition mmcblk0p1 found"
MSG_DE[$MSG_NO_BOOT_PARTITION]="??? RBK0011E: Keine boot Partition mmcblk0p1 gefunden"
MSG_NO_DATA_PARTITION=12
MSG_EN[$MSG_NO_DATA_PARTITION]=""			# reuse
MSG_DE[$MSG_NO_DATA_PARTITION]=""
MSG_MULTIPLE_PARTITIONS_FOUND=13
MSG_EN[$MSG_MULTIPLE_PARTITIONS_FOUND]="??? RBK0013E: More than two partitions detected which can be saved with backuptype DD or DDZ only"
MSG_DE[$MSG_MULTIPLE_PARTITIONS_FOUND]="??? RBK0013E: Es existieren mehr als zwei Partitionen, die nur mit dem Backuptype DD oder DDZ gesichert werden können"
MSG_EMAIL_PROG_NOT_SUPPORTED=14
MSG_EN[$MSG_EMAIL_PROG_NOT_SUPPORTED]="??? RBK0014E: eMail program %1 not supported. Only %2 supported"
MSG_DE[$MSG_EMAIL_PROG_NOT_SUPPORTED]="??? RBK0014E: eMail Programm %1 ist nicht unterstützt. Möglich sind %2"
MSG_ERROR_OCCURED=15
MSG_EN[$MSG_ERROR_OCCURED]="??? RBK0015E: Error occured with rc=%1"
MSG_DE[$MSG_ERROR_OCCURED]="??? RBK0015E: Ein Fehler ist aufgetreten mit Rückgabewert=%1"
MSG_EMAIL_HEADER=16
MSG_EN[$MSG_EMAIL_HEADER]="To: %1\nFrom: %2\nSubject: %3\n%4"
MSG_DE[$MSG_EMAIL_HEADER]="An: %1\nVon: %2\nThema: %3\n%4"
MSG_BACKUP_OK=17
MSG_EN[$MSG_BACKUP_OK]="--- RBK0017I: Backup finished successfully"
MSG_DE[$MSG_BACKUP_OK]="--- RBK0017I: Backup erfolgreich beendet"
MSG_BODY_ERROR=18
MSG_EN[$MSG_BODY_ERROR]="??? RBK0018I See logfile %1 for details. %2: %3 FAILED with RC %4 !!!" 
MSG_DE[$MSG_BODY_ERROR]="??? RBK0018I Logdatei %1 enthält weitere Detailinformationen. %2: %3 bricht mit RC %4 ab !!!" 
MSG_BODY_OK=19
MSG_EN[$MSG_BODY_OK]="--- RBK0019I: %1: %2 completed successfully" 
MSG_DE[$MSG_BODY_OK]="--- RBK0019I: %1: %2 erfolgreich beendet" 
MSG_FILESYSTEM_INCORRECT=20
MSG_EN[$MSG_FILESYSTEM_INCORRECT]="??? RBK0020E: Filesystem of rsync directory %1 has to be either ext3 or ext4"
MSG_DE[$MSG_FILESYSTEM_INCORRECT]="??? RBK0020E: Dateisystem des rsync Verzeichnisses %1 muss entweder ext3 oder ext4 sein"
MSG_RSYNC_NOT_INSTALLED=21
MSG_EN[$MSG_RSYNC_NOT_INSTALLED]="??? RBK0021E: rsync not installed"
MSG_DE[$MSG_RSYNC_NOT_INSTALLED]="??? RBK0021E: rsync ist nicht installiert"
MSG_UNKNOWN_BACKUPTYPE=22
MSG_EN[$MSG_UNKNOWN_BACKUPTYPE]="??? RBK0022E: Unknown backuptype %1"
MSG_DE[$MSG_UNKNOWN_BACKUPTYPE]="??? RBK0022E: Unbekannter Backtyp %1"
MSG_KEEPBACKUP_INVALID=23
MSG_EN[$MSG_KEEPBACKUP_INVALID]="??? RBK0023E: Invalid parameter %1 for -k"
MSG_DE[$MSG_KEEPBACKUP_INVALID]="??? RBK0023E: Ungültiger Parameter %1 für -k"
MSG_XBMC_DOESNOTEXIST=24
MSG_EN[$MSG_XBMC_DOESNOTEXIST]="??? RBK0024E: /home/pi/.xbmc does not exist"
MSG_DE[$MSG_XBMC_DOESNOTEXIST]="??? RBK0024E: /home/pi/.xbmc existiert nicht"
MSG_DIR_TO_BACKUP_DOESNOTEXIST=25
MSG_EN[$MSG_DIR_TO_BACKUP_DOESNOTEXIST]="??? RBK0025E: Backupdirectory %1 does not exist"
MSG_DE[$MSG_DIR_TO_BACKUP_DOESNOTEXIST]="??? RBK0025E: Backupverzeichnis %1 existiert nicht"
MSG_DIR_TO_BACKUP_ABSOLUTE=26
MSG_EN[$MSG_DIR_TO_BACKUP_ABSOLUTE]="??? RBK0026E: Backupdirectory %1 has to be absolute"
MSG_DE[$MSG_DIR_TO_BACKUP_ABSOLUTE]="??? RBK0026E: Backupverzeichnis %1 muss absolut sein"
MSG_NO_DEVICEMOUNTED=27
MSG_EN[$MSG_NO_DEVICEMOUNTED]="??? RBK0027E: No external device mounted on %1"
MSG_DE[$MSG_NO_DEVICEMOUNTED]="??? RBK0027E: Kein externes Gerät an %1 verbunden"
MSG_MAILPROGRAM_MISSING=28
MSG_EN[$MSG_MAILPROGRAM_MISSING]="??? RBK0028E: Mail program %1 not installed"
MSG_DE[$MSG_MAILPROGRAM_MISSING]="??? RBK0028E: Mail Programm %1 ist nicht installiert"
MSG_MPACK_NOT_INSTALLED=29
MSG_EN[$MSG_MPACK_NOT_INSTALLED]="??? RBK0029E: Mail program mpack not installed to send emails"
MSG_DE[$MSG_MPACK_NOT_INSTALLED]="??? RBK0029E: Mail Program mpack is nicht installiert"
MSG_BACKUPPATH_HASTOBEABSOLUTE=30
MSG_EN[$MSG_BACKUPPATH_HASTOBEABSOLUTE]="??? RBK0030E: Backuppath %1 has to be absolute"
MSG_DE[$MSG_BACKUPPATH_HASTOBEABSOLUTE]="??? RBK0030E: Backuppfad %1 muss absolut sein"
MSG_BACKUPPATH_DOESNOTEXIST=31
MSG_EN[$MSG_BACKUPPATH_DOESNOTEXIST]="??? RBK0031E: Backuppath %1 does not exist"
MSG_DE[$MSG_BACKUPPATH_DOESNOTEXIST]="??? RBK0031E: Backuppfad %1 exisitert nicht"
MSG_INVALID_LOG_LEVEL=32
MSG_EN[$MSG_INVALID_LOG_LEVEL]="!!! RBK0032W: Invalid parameter %1 for -l detected. Using %2"
MSG_DE[$MSG_INVALID_LOG_LEVEL]="!!! RBK0032W: Ungültiger Parameter %1 für -l eingegeben. Es wird %2 benutzt"
MSG_INVALID_LOG_OUTPUT=33
MSG_EN[$MSG_INVALID_LOG_OUTPUT]="!!! RBK0033W: Invalid parameter %1 for -L detected. Using %2"
MSG_DE[$MSG_INVALID_LOG_OUTPUT]="!!! RBK0032W: Ungültiger Parameter %1 für -L eingegeben. Es wird %2 benutzt"
MSG_FILE_NOT_FOUND=34
MSG_EN[$MSG_FILE_NOT_FOUND]="??? RBK0034E: File %1 not found"
MSG_DE[$MSG_FILE_NOT_FOUND]="??? RBK0034E: Datei %1 nicht gefunden"
MSG_LOG=35
MSG_EN[$MSG_LOG]="??? RBK0035E: File %1 not found"
MSG_DE[$MSG_LOG]="??? RBK0035E: Datei %1 nicht gefunden"
MSG_ANSWER_CHARS_NO=36
MSG_EN[$MSG_ANSWER_CHARS_NO]="Nn"
MSG_DE[$MSG_ANSWER_CHARS_NO]="Nn"
MSG_ANSWER_CHARS_YES=37
MSG_EN[$MSG_ANSWER_CHARS_YES]="Yy"
MSG_DE[$MSG_ANSWER_CHARS_YES]="Jj"
MSG_ANSWER_YES_NO=38
MSG_EN[$MSG_ANSWER_YES_NO]="--- RBK0038I: Are you sure? %1"
MSG_DE[$MSG_ANSWER_YES_NO]="--- RBK0038I: Bist Du sicher? %1"
MSG_MAILPROGRAM_NOT_INSTALLED=39
MSG_EN[$MSG_MAILPROGRAM_NOT_INSTALLED]="??? RBK0039E: Mail program %1 not installed to send emails"
MSG_DE[$MSG_MAILPROGRAM_NOT_INSTALLED]="??? RBK0039E: Mail Program %1 ist nicht installiert um eMail szu senden"
MSG_LOG_CONSOLE=40
MSG_EN[$MSG_LOG_CONSOLE]="--- RBK0040I: %1 %2 %3 %4 %5 %6 %7 %8 %9 %10 %11 %12 %13 %14 %15 %16 %17 %18 %19 %20"
MSG_DE[$MSG_LOG_CONSOLE]="--- RBK0040I: %1 %2 %3 %4 %5 %6 %7 %8 %9 %10 %11 %12 %13 %14 %15 %16 %17 %18 %19 %20"
MSG_TITLE_OK=41
MSG_EN[$MSG_TITLE_OK]="%1: Backup finished successfully"
MSG_DE[$MSG_TITLE_OK]="%1: Backup erfolgreich beendet"
MSG_TITLE_ERROR=42
MSG_EN[$MSG_TITLE_ERROR]="??? %1: Backup failed"
MSG_DE[$MSG_TITLE_ERROR]="??? %1: Backup nicht erfolgreich"
MSG_REMOVING_BACKUP=43
MSG_EN[$MSG_REMOVING_BACKUP]="??? RBK0043E: Removing incomplete backup %1 (May take some time. Be patient)"
MSG_DE[$MSG_REMOVING_BACKUP]="??? RBK0043E: Unvollständiges Backup %1 wird gelöscht (Kann etwas dauern. Bitte etwas Geduld)"
MSG_CREATING_BOOT_BACKUP=44
MSG_EN[$MSG_CREATING_BOOT_BACKUP]="--- RBK0044I: Creating backup of boot partition in %1"
MSG_DE[$MSG_CREATING_BOOT_BACKUP]="--- RBK0044I: Backup der Bootpartition wird in %1 erstellt"
MSG_CREATING_PARTITION_BACKUP=45
MSG_EN[$MSG_CREATING_PARTITION_BACKUP]="--- RBK0045I: Creating backup of partition layout in %1"
MSG_DE[$MSG_CREATING_PARTITION_BACKUP]="--- RBK0044I: Backup des Partitionlayouts wird in %1 erstellt"
MSG_CREATING_MBR_BACKUP=46
MSG_EN[$MSG_CREATING_MBR_BACKUP]="--- RBK0046I: Creating backup of master boot record in %1"
MSG_DE[$MSG_CREATING_MBR_BACKUP]="--- RBK0046I: Backup des Masterbootrecords wird in %1 erstellt"
MSG_START_SERVICES_FAILED=47
MSG_EN[$MSG_START_SERVICES_FAILED]="--- RBK0047E: Error occured when starting services"
MSG_DE[$MSG_START_SERVICES_FAILED]="--- RBK0047E: Ein Fehler trat beim Starten von Services auf"
MSG_STOP_SERVICES_FAILED=48
MSG_EN[$MSG_STOP_SERVICES_FAILED]="--- RBK0048E: Error occured when stopping services"
MSG_DE[$MSG_STOP_SERVICES_FAILED]="--- RBK0048E: Ein Fehler trat beim Stoppen von Services auf"
MSG_FILES_CHANGE_DURING_BACKUP=49
MSG_EN[$MSG_FILES_CHANGE_DURING_BACKUP]="--- RBK0049W: Some files were changed or vanished during backup. RC: %1 - ignoring change"
MSG_DE[$MSG_FILES_CHANGE_DURING_BACKUP]="--- RBK0049W: Einige Dateien haben sich während des Backups geändert oder sind verschwunden. RC: %1 - Änderung wird ignoriert"
MSG_RESTORING_FILE=50
MSG_EN[$MSG_RESTORING_FILE]="--- RBK0050I: Restoring from backup %1"
MSG_DE[$MSG_RESTORING_FILE]="--- RBK0050I: Backup wird von %1 zurückgespielt"
MSG_RESTORING_MBR=51
MSG_EN[$MSG_RESTORING_MBR]="--- RBK0051I: Restoring mbr from %1 to %2"
MSG_DE[$MSG_RESTORING_MBR]="--- RBK0051I: Master boot backup wird von %1 auf %2 zurückgespielt"
MSG_CREATING_PARTITIONS=52
MSG_EN[$MSG_CREATING_PARTITIONS]="--- RBK0052I: Creating partition(s) on SD card"	
MSG_DE[$MSG_CREATING_PARTITIONS]="--- RBK0052I: Partition(en) werden auf der SD Karte erstellt"	
MSG_RESTORING_FIRST_PARTITION=53
MSG_EN[$MSG_RESTORING_FIRST_PARTITION]="--- RBK0053I: Restoring first partition (boot partition) %1"	
MSG_DE[$MSG_RESTORING_FIRST_PARTITION]="--- RBK0053I: Erste Partition (Bootpartition) %1 wird zurückgespielt"	
MSG_FORMATTING_SECOND_PARTITION=54
MSG_EN[$MSG_FORMATTING_SECOND_PARTITION]="--- RBK0054I: Formating second partition (root partition) %1"
MSG_DE[$MSG_FORMATTING_SECOND_PARTITION]="--- RBK0052I: Zweite Partition (Rootpartition) %1 wird zurpckgespielt"
MSG_RESTORING_SECOND_PARTITION=55
MSG_EN[$MSG_RESTORING_SECOND_PARTITION]="--- RBK0055I: Restoring second partition (root partition) %1"	
MSG_DE[$MSG_RESTORING_SECOND_PARTITION]="--- RBK0055I: Zweite Partition (Rootpartition) %1 wird zurückgespielt"	
MSG_RESTORING_FILE_DONE=56
MSG_EN[$MSG_RESTORING_FILE_DONE]="--- RBK0056I: Restore finished"	
MSG_DE[$MSG_RESTORING_FILE_DONE]="--- RBK0056I: Zurückspielen des Backups beendet"	
MSG_ASSERTION_FAILED=57
MSG_EN[$MSG_ASSERTION_FAILED]="--- RBK0057E: Assertion failed in line %1"	
MSG_DE[$MSG_ASSERTION_FAILED]="--- RBK0057E: Interner Fehler in Zeile %1"	
MSG_INVALID_MSG_LEVEL=58
MSG_EN[$MSG_INVALID_MSG_LEVEL]="!!! RBK0058W: Invalid parameter %1 for -m detected. Using %2"
MSG_DE[$MSG_INVALID_MSG_LEVEL]="!!! RBK0058W: Ungültiger Parameter %1 für -m eingegeben. Es wird %2 benutzt"
MSG_INVALID_LOG_OUTPUT=59
MSG_EN[$MSG_INVALID_LOG_OUTPUT]="!!! RBK0059W: Invalid parameter %1 for -L detected. Using %2"
MSG_DE[$MSG_INVALID_LOG_OUTPUT]="!!! RBK0059W: Ungültiger Parameter %1 für -L eingegeben. Es wird %2 benutzt"
MSG_NO_YES=60
MSG_EN[$MSG_NO_YES]="no yes"
MSG_DE[$MSG_NO_YES]="nein ja"
MSG_RESTOREFILE_ABSOLUTE=61
MSG_EN[$MSG_RESTOREFILE_ABSOLUTE]="??? RBK0061E: Backup file/directory %1 has to be specified absolute"
MSG_DE[$MSG_RESTOREFILE_ABSOLUTE]="??? RBK0061E: Backupdatei/-verzeichnis %1 muss absolut angegeben werden"
MSG_NO_RESTOREDEVICE_DEFINED=62
MSG_EN[$MSG_NO_RESTOREDEVICE_DEFINED]="??? RBK0062E: No restoredevice defined (Example: /dev/sda)"
MSG_DE[$MSG_NO_RESTOREDEVICE_DEFINED]="??? RBK0062E: Kein Zurückspielgerät ist definiert (Beispiel: /dev/sda)"
MSG_NO_RESTOREDEVICE_FOUND=63
MSG_EN[$MSG_NO_RESTOREDEVICE_FOUND]="??? RBK0063E: Restoredevice %1 not found (Example: /dev/sda)"
MSG_DE[$MSG_NO_RESTOREDEVICE_FOUND]="??? RBK0063E: Zurückspielgerät %1 existiert nicht (Beispiel: /dev/sda)"
MSG_ROOT_PARTTITION_NOT_FOUND=64
MSG_EN[$MSG_ROOT_PARTTITION_NOT_FOUND]="??? RBK0064E: Partition for rootpartition %1 not found (Example: /dev/sdb1)"
MSG_DE[$MSG_ROOT_PARTTITION_NOT_FOUND]="??? RBK0064E: Partition für die Rootpartition %1 nicht gefunden (Beispiel: /dev/sda)"
MSG_REPARTITION_WARNING=65
MSG_EN[$MSG_REPARTITION_WARNING]="!!! RBK0065W: Device %1 will be repartitioned and all data will be lost"
MSG_DE[$MSG_REPARTITION_WARNING]="!!! RBK0065W: Gerät %1 wird repartitioniert und die gesamten Daten werden gelöscht"
MSG_WARN_RESTORE_DEVICE_OVERWRITTEN=66
MSG_EN[$MSG_WARN_RESTORE_DEVICE_OVERWRITTEN]="!!! RBK0066W: Device %1 will get the restored boot partition and root partition"
MSG_DE[$MSG_WARN_RESTORE_DEVICE_OVERWRITTEN]="!!! RBK0066W: Gerät %1 wird die wiederhergestellte Bootpartition und Rootpartition erhalten"
MSG_CURRENT_PARTITION_TABLE=67
MSG_EN[$MSG_CURRENT_PARTITION_TABLE]="--- RBK0067I: Current partitions on %1:$NL%2 %3 %4 %5 %6 %7 %8 %9 %10 %11 %12 %13 %14 %15 %16 %17 %18 %19 %20 %21 %22 %23 %24 %25 %26 %27 %28 %29"
MSG_DE[$MSG_CURRENT_PARTITION_TABLE]="--- RBK0067I: Momentane Partitionen auf %1: $NL%2 %3 %4 %5 %6 %7 %8 %9 %10 %11 %12 %13% 14 %15 %16 %17 %18 %19 %20 %21 %22 %23 %24 %25 %26 %27 %28 %29"
MSG_CURRENT_PARTITION_TABLE_FDISK=68
MSG_EN[$MSG_CURRENT_PARTITION_TABLE_FDISK]="--- RBK0068I: %1"
MSG_DE[$MSG_CURRENT_PARTITION_TABLE_FDISK]="--- RBK0068I: %1"
MSG_WARN_BOOT_PARTITION_OVERWRITTEN=69
MSG_EN[$MSG_WARN_BOOT_PARTITION_OVERWRITTEN]="!!! RBK0069W: Bootpartition %1 will be formatted and will get the restored Boot partition"
MSG_DE[$MSG_WARN_BOOT_PARTITION_OVERWRITTEN]="!!! RBK0069W: Bootpartition %1 wird formatiert und erhält die zurückgespielte Bootpartition"
MSG_WARN_ROOT_PARTITION_OVERWRITTEN=70
MSG_EN[$MSG_WARN_ROOT_PARTITION_OVERWRITTEN]="!!! RBK0070W: Rootpartition %1 will be formatted and will get the restored Root partition"	
MSG_DE[$MSG_WARN_ROOT_PARTITION_OVERWRITTEN]="!!! RBK0070W: Rootpartition %1 wird formatiert und erhält die zurückgespielte Rootpartition"
MSG_QUERY_CHARS_YES_NO=71
MSG_EN[$MSG_QUERY_CHARS_YES_NO]="y/N"
MSG_DE[$MSG_QUERY_CHARS_YES_NO]="j/N"
MSG_SCRIPT_UPDATE_OK=72
MSG_EN[$MSG_SCRIPT_UPDATE_OK]="--- RBK0072I: %1 updated from version %2 to current version %3. Previous version saved as %4"
MSG_DE[$MSG_SCRIPT_UPDATE_OK]="--- RBK0072I: %1 von Version %2 durch die aktuelle Version %3 ersetzt. Die vorherige Verion wurde als %4 gesichert"
MSG_SCRIPT_UPDATE_NOT_NEEDED=73
MSG_EN[$MSG_SCRIPT_UPDATE_NOT_NEEDED]="--- RBK0073I: %1 already current with version %2"
MSG_DE[$MSG_SCRIPT_UPDATE_NOT_NEEDED]="--- RBK0073I: %1 bereits auf der aktuellen Version %2"
MSG_SCRIPT_UPDATE_FAILED=74
MSG_EN[$MSG_SCRIPT_UPDATE_FAILED]="!!! RBK0074E: Failed to update %1"
MSG_DE[$MSG_SCRIPT_UPDATE_FAILED]="!!! RBK0074E: %1 konnte nicht ersetzt werden"
MSG_NEW_VERSION_AVAILABLE=75
MSG_EN[$MSG_NEW_VERSION_AVAILABLE]="--- RBK0075I: There is a new version %1 of the script available"
MSG_DE[$MSG_NEW_VERSION_AVAILABLE]="--- RBK0075I: Es gibt eine aktuellere Version %1 des Scripts"
MSG_RESTORE_OK=76
MSG_EN[$MSG_RESTORE_OK]="--- RBK0076I: Restore finished successfully"
MSG_DE[$MSG_RESTORE_OK]="--- RBK0076I: Restore erfolgreich beendet"
MSG_RESTORE_FAILED=77
MSG_EN[$MSG_RESTORE_FAILED]="??? RBK0077E: Restore failed in task %1 with RC %2. See logfile %3 for details"
MSG_DE[$MSG_RESTORE_FAILED]="??? RBK0077E: Restore fehlerhaft in Schritt %1 mit RC %2 beendet. Weitere Informationen finden sich im Logfile %3"
MSG_SCRIPT_UPDATE_NOT_UPLOADED=78
MSG_EN[$MSG_SCRIPT_UPDATE_NOT_UPLOADED]="--- RBK0078I: %1 with version %2 is newer than uploaded version %3"
MSG_DE[$MSG_SCRIPT_UPDATE_NOT_UPLOADED]="--- RBK0078I: %1 mit der Version %2 ist neuer als die uploaded Version %3"
MSG_UNKNOWN_BACKUPTYPE_FOR_ZIP=79
MSG_EN[$MSG_UNKNOWN_BACKUPTYPE_FOR_ZIP]="??? RBK0079E: Invalid backuptype %1 for option -z"
MSG_DE[$MSG_UNKNOWN_BACKUPTYPE_FOR_ZIP]="??? RBK0079E: Unbekannter Backuptyp %1 für Option -z"
MSG_NEW_VERSION_AVAILABLE=80
MSG_EN[$MSG_NEW_VERSION_AVAILABLE]="--- RBK0080I: ;-) There is a newer script version %1 available for download. You are running version %2 and now can use parameter -U to upgrade your local version."
MSG_DE[$MSG_NEW_VERSION_AVAILABLE]="--- RBK0080I: ;-) Es gibt eine neuere Scriptversion %1 zum downloaden. Die momentan benutze Version ist %2 und nun kann mit dem Parameter -U die lokale Version aktualisiert werden."
MSG_BACKUP_TARGET=81
MSG_EN[$MSG_BACKUP_TARGET]="--- RBK0081I: Creating backup of type %1 in %2"
MSG_DE[$MSG_BACKUP_TARGET]="--- RBK0081I: Backup vom Typ %1 wird in %2 erstellt"
MSG_EXISTING_BOOT_BACKUP=82
MSG_EN[$MSG_EXISTING_BOOT_BACKUP]="--- RBK0082I: Backup of boot partition alreday exists in %1"
MSG_DE[$MSG_EXISTING_BOOT_BACKUP]="--- RBK0082I: Backup der Bootpartition in %1 existiert schon"
MSG_EXISTING_PARTITION_BACKUP=83
MSG_EN[$MSG_EXISTING_PARTITION_BACKUP]="--- RBK0083I: Backup of partition layout already exists in %1"
MSG_DE[$MSG_EXISTING_PARTITION_BACKUP]="--- RBK0083I: Backup des Partitionlayouts in %1 existiert schon"
MSG_EXISTING_MBR_BACKUP=84
MSG_EN[$MSG_EXISTING_MBR_BACKUP]="--- RBK0084I: Backup of master boot record already exists in %1"
MSG_DE[$MSG_EXISTING_MBR_BACKUP]="--- RBK0084I: Backup des Masterbootrecords in %1 existiert schon"
MSG_BACKUP_STARTED=85
MSG_EN[$MSG_BACKUP_STARTED]="--- RBK0085I: Backup creation of type %1 progressing. This will take some time"
MSG_DE[$MSG_BACKUP_STARTED]="--- RBK0085I: Backuperstellung vom Typ %1 läuft. Das wird etwas dauern"
MSG_RESTOREDEVICE_IS_PARTITION=86
MSG_EN[$MSG_RESTOREDEVICE_IS_PARTITION]="??? RBK0086E: Restore device cannot be a partition"
MSG_DE[$MSG_RESTOREDEVICE_IS_PARTITION]="??? RBK0086E: Wiederherstellungsgerät darf keine Partition sein"
MSG_RESTORE_FILE_INVALID=87
MSG_EN[$MSG_RESTORE_FILE_INVALID]="??? RBK0087E: Invalid restore file or directory %1"
MSG_DE[$MSG_RESTORE_FILE_INVALID]="??? RBK0087E: Wiederherstellungsdatei %1 ist ungültig"
MSG_MISSING_OPTION=88
MSG_EN[$MSG_MISSING_OPTION]="??? RBK0088E: Missing option(s) %1"
MSG_DE[$MSG_MISSING_OPTION]="??? RBK0088E: Aufrufoption(en) %1 fehlen"
MSG_UNKNOWN_OPTION=89
MSG_EN[$MSG_UNKNOWN_OPTION]="??? RBK0089E: Unknown option %1"
MSG_DE[$MSG_UNKNOWN_OPTION]="??? RBK0089E: Unbekannte Aufrufoption %1"
MSG_OPTION_REQUIRES_PARAMETER=90
MSG_EN[$MSG_OPTION_REQUIRES_PARAMETER]="??? RBK0090E: Option %1 requires a parameter"
MSG_DE[$MSG_OPTION_REQUIRES_PARAMETER]="??? RBK0090E: Aufrufoption %1 erwartet ein Argument"
MSG_MENTION_HELP=91
MSG_EN[$MSG_MENTION_HELP]="--- RBK0091I: Invoke '%1 -h' to get more detailed information about script invocation parameters"
MSG_DE[$MSG_MENTION_HELP]="--- RBK0091I: '%1 -h' liefert eine detailierte Beschreibung der Scriptaufrufoptionen" 
MSG_LANGUAGE_NOT_SUPPORTED=96
MSG_EN[$MSG_LANGUAGE_NOT_SUPPORTED]="--- RBK0096W: Language %1 not supported. %2 will be used instead"
MSG_DE[$MSG_LANGUAGE_NOT_SUPPORTED]="--- RBK0096W: Die Sprache %1 wird nicht unterstützt. %2 wird benutzt"
MSG_VERSION_HISTORY_PAGE=102
MSG_EN[$MSG_VERSION_HISTORY_PAGE]="http://www.linux-tips-and-tricks.de/en/versionhistory/"
MSG_DE[$MSG_VERSION_HISTORY_PAGE]="http://www.linux-tips-and-tricks.de/de/versionshistorie/" 
MSG_VISIT_VERSION_HISTORY_PAGE=103
MSG_EN[$MSG_VISIT_VERSION_HISTORY_PAGE]="--- RBK0103I: Please visit %1 to see a list of latest changes included in the new version"
MSG_DE[$MSG_VISIT_VERSION_HISTORY_PAGE]="--- RBK0103I: Bitte %1 besuchen, um die neuesten Änderungen in der neuen Version zu erfahren" 
MSG_UNABLE_TO_WRITE=104
MSG_EN[$MSG_UNABLE_TO_WRITE]="??? RBK0104E: Unable to create backup on %1 because of missing access permissions"
MSG_DE[$MSG_UNABLE_TO_WRITE]="??? RBK0104E: Ein Backup kann nicht auf %1 erstellt werden da Zugriffsberechtigungen fehlen" 
MSG_INCLUDED_CONFIG=105
MSG_EN[$MSG_INCLUDED_CONFIG]="--- RBK0105I: Using config file %1"
MSG_DE[$MSG_INCLUDED_CONFIG]="--- RBK0105I: Konfigurationsdatei %1 wird benutzt" 

# Create message and substitute parameters

function getMessageText() {         # languageflag messagenumber parm1 parm2 ...
    local msg
    local p
    local i
	local s

	if [[ $1 != "L" ]]; then
		LANG_SUFF=$(echo $1 | tr '[:lower:]' '[:upper:]')
	else
		LANG_EXT=$(echo $LANG | tr '[:lower:]' '[:upper:]')
		LANG_SUFF=${LANG_EXT:0:2}
	fi

	msgVar="MSG_${LANG_SUFF}"

    if [[ -n ${!msgVar} ]]; then
		msgVar="$msgVar[$2]"
        msg=${!msgVar}
        if [[ -z $msg ]]; then		       			# no translation found
			msg="${MSG_EN[$2]}";      	    	    # fallback into english
		fi
     else
		 msg="${MSG_EN[$2]}";      	      	        # fallback into english
     fi

   for (( i=3; $i <= $#; i++ )); do            		# substitute all message parameters
      p=${!i}
      let s=$i-2
      s="%$s"
      msg="$( perl -p -e "s|$s|$p|" <<< "$msg" )"			# have to use explicit command name 
   done
   
   msg="$( perl -p -e "s/%[0-9]+//g" <<< "$msg" 2>/dev/null)"     # delete trailing %n definitions
   echo "$msg"
}

# Borrowed from http://stackoverflow.com/questions/85880/determine-if-a-function-exists-in-bash

fn_exists() {
  [ `type -t $1`"" == 'function' ]
}

function callExtensions() { # extension_plugpoint rc

	local extension
	
	for extension in $EXTENSIONS; do
	
		local extensionFileName="${MYNAME}_${extension}_$1.sh"
		
		if which $extensionFileName 2>&1 1>/dev/null; then
			logItem "Calling $extensionFileName $2"
			set -e
			executeShellCommand ". $extensionFileName $2"
			set +e
		else
			logItem "$extensionFileName not found - skipping"
		fi
	done

}

# usage

function usage() {
	
	LANG_SUFF=$LANGUAGE

	NO_YES=( $(getLocalizedMessage $MSG_NO_YES) )

	local func="usage${LANG_SUFF}"

	if ! fn_exists $func; then     
		func="usageEN"
	fi
	
	$func

}

# --- Helper function to extract the message text in German or English and insert message parameters

function getLocalizedMessage() { # messageNumber parm1 parm2

	local msg
	msg="$(getMessageText $LANGUAGE "$@")"	
	echo "$msg"
}

# Write message

function writeToConsole() {  # msglevel messagenumber message
	local msg level
	
	level=$1
	shift

	if [[ ( $level -le $MSG_LEVEL ) ]]; then

		msg="$(getMessageText $LANGUAGE "$@")"

		if (( $INTERACTIVE )); then
			echo -e "$msg" > /dev/tty
		else
			echo -e "$msg" >> "$LOG_FILE"
		fi
		
		echo -e "$msg" >> "$LOG_MAIL_FILE"
		logIntoOutput $LOG_TYPE_MSG "$msg"
	fi
}

# setup trap function
# trap function then will be called with trap as argument

function trapWithArg() { # function trap1 trap2 ... trapn
    func="$1" ; shift
    for sig ; do
        trap "$func $sig" "$sig"
    done
}

function abort() { # lineno
	writeToConsole $MSG_LEVEL_MINIMAL $MSG_ASSERTION_FAILED "$1"
	exit 127
}

function executeCommand() { # command
	if (( $VERBOSE )); then
		eval "$1"
	else
		eval "$1" >/dev/null 2>>"$LOG_FILE"
	fi			
	rc=$?
}

function executeShellCommand() { # command

	logItem "Executing $*"
	eval "$*" 1>>"$LOG_FILE" 2>&1
    rc=$?	
	logItem "Result $rc"
}

function logIntoOutput() { # logtype message

	local type dte 
	type=$1
	shift

	dte=$(date +%Y%m%d-%H%M%S)

	case $LOG_OUTPUT in
		$LOG_OUTPUT_SYSLOG)
			logger -t $MYSELF -- "${LOG_TYPEs[$type]} $@"
			;;
		$LOG_OUTPUT_VARLOG | $LOG_OUTPUT_BACKUPLOC | $LOG_OUTPUT_HOME)
			echo "$dte: ${LOG_TYPEs[$type]} $@" >> "$LOG_FILE"
			;;
		$LOG_OUTPUT_MAIL)
			echo "$dte: ${LOG_TYPEs[$type]} $@" >> "$LOG_MAIL_FILE"
			;;		
		*) 
			echo "Internal error - invalid log destination"
			abort $LINENO
			;;
	esac
}

function repeat() { # char num
	local s
	s=$( yes $1 | head -$2 | tr -d "\n" )
	echo $s
}

currentTask="main"
taskStack=( $currentTask )

function pushTask() { #task
	taskStack=("${taskStack[@]}" $1)
}

function popTask() { # resultVariableNAME 	
	local resultVar=$1					# uggly bash hack to return result
	local r
	r=${taskStack[${#taskStack[@]}-1]} 	# restore previous 
	unset taskStack[${#taskStack[@]}-1] # remove current 
	eval $resultVar="'$r'"
}

function logItem() { # message 
	if [[ $LOG_DEBUG == $LOG_LEVEL ]]; then
		logIntoOutput $LOG_TYPE_DEBUG "-- $1"
	fi
}

function logEntry() { # message 
	if [[ $LOG_DEBUG == $LOG_LEVEL ]]; then
		pushTask $currentTask			# push current task
		currentTask=$1
		logIntoOutput $LOG_TYPE_DEBUG ">> $1"
	fi
}

function logExit() { # message	
	if [[ $LOG_DEBUG == $LOG_LEVEL ]]; then
		logIntoOutput $LOG_TYPE_DEBUG "<< $1"
		popTask currentTask				# pop previous task
	fi		
}

function logOptions() {
	
	logItem "Options: $passedOpts"	
	logItem "BACKUPPATH=$BACKUPPATH"
	logItem "KEEPBACKUPS=$KEEPBACKUPS"
	logItem "BACKUPTYPE=$BACKUPTYPE"
	logItem "STOPSERVICES=$STOPSERVICES"
	logItem "STARTSERVICES=$STARTSERVICES"
	logItem "EMAIL=$EMAIL"
	logItem "EMAIL_PARMS=$EMAIL_PARMS"
	logItem "DIR_TO_BACKUP=$DIR_TO_BACKUP"
	logItem "LOG_LEVEL=$LOG_LEVEL"
	logItem "MSG_LEVEL=$MSG_LEVEL"
	logItem "MAIL_PROGRAM=$EMAIL_PROGRAM"
	logItem "APPEND_LOG=$APPEND_LOG"
 	logItem "VERBOSE=$VERBOSE"
 	logItem "CONFIG_FILE=$CONFIG_FILE"
 	logItem "LOG_OUTPUT=$LOG_OUTPUT"
 	logItem "SKIPLOCALCHECK=$SKIPLOCALCHECK"
 	logItem "DD_BLOCKSIZE=$DD_BLOCKSIZE"
 	logItem "DD_PARMS=$DD_PARMS"
 	logItem "HARDLINKS=$HARDLINKS"
	logItem "RESTORE_DEVICE=$RESTORE_DEVICE"
	logItem "ROOT_PARTITION=$ROOT_PARTITION"
	logItem "EXCLUDE_LIST=$EXCLUDE_LIST"
	logItem "ZIP_BACKUP=$ZIP_BACKUP"
	logItem "NOTIFY_UPDATE=$NOTIFY_UPDATE"
	logItem "EXTENSIONS=$EXTENSIONS"
	logItem "PARTITIONBASED_BACKUP=$PARTITIONBASED_BACKUP"
	logItem "LANGUAGE=$LANGUAGE"
}

rc=0

LOG_MAIL_FILE="./${MYNAME}.maillog"
#logItem "Removing maillog file ${LOG_MAIL_FILE}"
rm -f "$LOG_MAIL_FILE" 2>&1 1>/dev/null
LOG_FILE="./${MYNAME}.log"
#logItem "Removing log file ${LOG_FILE}"
rm -f "$LOG_FILE" 2>&1 1>/dev/null

LATEST_VERSION_FILE="/tmp/${MYSELF}~"	

############# Begin default config section #############

# Part or whole of the following section can be put into 
# /usr/local/etc/raspiBackup.conf or ~/.raspiBackup.conf 
# and will take precedence over the following default definitions

# path to store the backupfile
DEFAULT_BACKUPPATH="/backup"
# how many backups to keep
DEFAULT_KEEPBACKUPS=3	
# type of backup: dd, tar, xbmc or rsync
DEFAULT_BACKUPTYPE="dd"
# zip tar or dd backup (0 = false, 1 = true)
DEFAULT_ZIP_BACKUP=0
# commands to stop services before backup separated by ;
DEFAULT_STOPSERVICES=""
# commands to start services after backup separated by ;
DEFAULT_STARTSERVICES=""
# email to send completion status
DEFAULT_EMAIL="" 
# Additional parameters for email program
DEFAULT_EMAIL_PARMS="" 
# log level  (0 = none, 1 = debug)
DEFAULT_LOG_LEVEL=0
# log output ( 0 = syslog, 1 = /var/log, 2 = backuppath)
DEFAULT_LOG_OUTPUT=1 
# msg level (0 = minimal, 1 = detailed)
DEFAULT_MSG_LEVEL=0
# mailprogram
DEFAULT_MAIL_PROGRAM="mail"
# restore device
DEFAULT_RESTORE_DEVICE=""
# default append log (0 = false, 1 = true)
DEFAULT_APPEND_LOG=0
# default verbose log (0 = false, 1 = true)
DEFAULT_VEBOSE=0 
# skip check for remote mount of backup path (0 = false, 1 = true)
DEFAULT_SKIPLOCALCHECK=0 
# blocksize used for dd 
DEFAULT_DD_BLOCKSIZE=1MB
# addition parms used for dd 
DEFAULT_DD_PARMS=""
# use hardlinks for rsync (0 = false, 1 = true)
DEFAULT_HARDLINKS=1 
# exclude list
DEFAULT_EXCLUDE_LIST=""
# notify in email if there is an updated script version available  (0 = false, 1 = true)
DEFAULT_NOTIFY_UPDATE=1 
# extensions to call
DEFAULT_EXTENSIONS=""
# partition based backup  (0 = false, 1 = true)
DEFAULT_PARTITIONBASED_BACKUP=0
# language (DE or EN)
DEFAULT_LANGUAGE=""

############# End default config section #############

# nice function to get user who invoked this script via sudo
# Borrowed from http://stackoverflow.com/questions/4598001/how-do-you-find-the-original-user-through-multiple-sudo-and-su-commands

function findUser() {
    thisPID=$$
    origUser=$(whoami)
    thisUser=$origUser

    while [ "$thisUser" = "$origUser" ]; do
		if [ "$thisPID" = "0" ]; then
			thisUser="root"
			break
		fi
        ARR=($(ps h -p$thisPID -ouser,ppid;))
        thisUser="${ARR[0]}"
        myPPid="${ARR[1]}"
        thisPID=$myPPid
    done

    getent passwd "$thisUser" | cut -d: -f1
}

function isNewVersionAvailable() { # skip check

	logEntry "isNewVersionAvailable"	

	local DIR
	local oldVersion="0.0"
	local newVersion="0.0"
	local latestVersion="0.0"
	local rc=2

	if [[ -z $1 ]]; then
		local lastCheckTime
		if [[ -e /tmp/$MYNAME.lastcheck ]]; then
			lastCheckTime=$(</tmp/$MYNAME.lastcheck)
		else
			lastCheckTime="00000000"
		fi
	
		local currentTime=$(date +%Y%m%d)

		logItem "$currentTime : $lastCheckTime"
	
		if [[ $currentTime == $lastCheckTime ]]; then
			logItem "Skip update check"
			rc=1
		else
			echo $currentTime > /tmp/$MYNAME.lastcheck
		fi
	fi

	if [[ $rc != 1 ]]; then
		DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

		logItem "Downloading $LATEST_VERSION_FILE"
		if wget $VERSION_CHECK_URL -q --tries=3 --timeout=3 -O $LATEST_VERSION_FILE; then
			newVersion=$(cat $LATEST_VERSION_FILE)
			oldVersion=$(grep "^VERSION=" $DIR/$MYSELF | cut -f 2 -d = | sed  "s/\"//g" | sed "s/ .*#.*//")
			latestVersion=$(echo -e "$newVersion\n$oldVersion" | sort -V | tail -1)
			logItem "new: $newVersion"
			logItem "old: $oldVersion"
			logItem "latest: $latestVersion"
			rm $LATEST_VERSION_FILE 1>/dev/null 2>&1
			if [[ $oldVersion != $newVersion ]]; then
				if [[ $oldVersion != $latestVersion ]]; then
					rc=0	# return new version
				else
					rc=3	# current version is latest version
				fi
			else
				rc=1	# no update available
			fi
		else
			rc=2		# update not possible
		fi
	fi

	result="$latestVersion $newVersion $oldVersion"

	echo "$result"
	
	logItem "Returning: $result RC: $rc"	
	logExit "isNewVersionAvailable"
	
	return $rc

}

function stopServices() {
	
	logEntry "stopServices"
	if [ -n "$STOPSERVICES" ]; then
		writeToConsole $MSG_LEVEL_DETAILED $MSG_STOPPING_SERVICES "$STOPSERVICES"
		logItem "$STOPSERVICES"
		executeShellCommand "$STOPSERVICES"
		if [[ $rc != 0 ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_STOP_SERVICES_FAILED
			exit 127
		fi
	fi
	logExit "stopServices"
}

function startServices() {
	
	logEntry "startServices"
	if [ -n "$STARTSERVICES" ]; then
		writeToConsole $MSG_LEVEL_DETAILED $MSG_STARTING_SERVICES "$STARTSERVICES"
		logItem "$STARTSERVICES"
		executeShellCommand $STARTSERVICES
		if [[ $rc != 0 ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_START_SERVICES_FAILED 
		fi
	fi
	logExit "startServices"
}

# update script with latest version if needed

function updateScript() {

	logEntry "updateScript"	

	local v
	local rc
	local DIR
	local versions
	local latestVersion
	local newVersion
	local oldVersion
	local newName
		
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	versions=( $(isNewVersionAvailable "skipCheck") )
	rc=$?
	
	latestVersion=${versions[0]}
	newVersion=${versions[1]}
	oldVersion=${versions[2]}
	
	if [[ $rc == 0 ]] && wget $DOWNLOAD_URL -q --tries=3 --timeout=3 -O $MYSELF~; then
		newName="$DIR/$MYNAME.$oldVersion.sh"
		mv $DIR/$MYSELF $newName
		mv $MYSELF~ $DIR/$MYSELF
		chown --reference=$newName $DIR/$MYSELF
		chmod --reference=$newName $DIR/$MYSELF
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_SCRIPT_UPDATE_OK "$DIR/$MYSELF" "$oldVersion" "$newVersion" "$newName"
	else
		rm $MYSELF~ 1>/dev/null 2>&1
		if [[ $rc == 1 ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_SCRIPT_UPDATE_NOT_NEEDED "$DIR/$MYSELF" "$newVersion" 
		elif [[ $rc == 3 ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_SCRIPT_UPDATE_NOT_UPLOADED "$DIR/$MYSELF" "$latestVersion" "$newVersion"
		else
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_SCRIPT_UPDATE_FAILED "$MYSELF" 
		fi
	fi
	
	logExit "updateScript"	

}

# check if directory is located on a mounted device

function isMounted() {

	local path
	path=$1

	while [[ "$path" != "" ]]; do
		if mountpoint -q "$path"; then
			return 0
        fi
        path=${path%/*}
	done
    return 1
}

function readConfigParameters() {

	ETC_CONFIG_FILE="/usr/local/etc/${MYNAME}.conf"
	HOME_CONFIG_FILE="/home/$(findUser)/.${MYNAME}.conf"

	# Override default parms with parms in global config file

	ETC_CONFIG_FILE_INCLUDED=0
	if [ -f $ETC_CONFIG_FILE ]; then
		set -e
		. $ETC_CONFIG_FILE
		set +e
		ETC_CONFIG_FILE_INCLUDED=1
	fi

	# Override default parms with parms in user config file

	HOME_CONFIG_FILE_INCLUDED=0
	if [ -f $HOME_CONFIG_FILE ]; then
		set -e
		. $HOME_CONFIG_FILE
		set +e
		HOME_CONFIG_FILE_INCLUDED=1
	fi

}

function setupEnvironment() {

	if [[ -z "$RESTOREFILE" ]]; then

		ZIP_BACKUP_TYPE_INVALID=0		# logging not enabled right now, invalid backuptype will be handled later
		if (( $ZIP_BACKUP )); then
			if [[ $BACKUPTYPE == $BACKUPTYPE_DD || $BACKUPTYPE == $BACKUPTYPE_TAR ]]; then
				BACKUPTYPE=${Z_TYPE_MAPPING[${BACKUPTYPE}]}	# tar-> tgz and dd -> ddz
			else
				ZIP_BACKUP_TYPE_INVALID=1
			fi
		fi

		BACKUPFILE_NODATE="$HOSTNAME-backup"
		BACKUPFILE="$HOSTNAME-$BACKUPTYPE-backup-$DATE"
		BACKUPTARGET_ROOT="$BACKUPPATH/$HOSTNAME"
	
		if [[ $BACKUPTYPE == $BACKUPTYPE_RSYNC ]]; then	
			BACKUPTARGET_DIR="$BACKUPTARGET_ROOT/$BACKUPFILE"
			BACKUPTARGET_FILE="$BACKUPTARGET_DIR/../$BACKUPFILE"	
			BACKUPTARGET_LOG_FILE="$BACKUPTARGET_DIR/../$BACKUPFILE"	
		else
			BACKUPTARGET_DIR="$BACKUPTARGET_ROOT"
			BACKUPTARGET_FILE="$BACKUPTARGET_DIR/$BACKUPFILE${FILE_EXTENSION[$BACKUPTYPE]}"	
			BACKUPTARGET_LOG_FILE="$BACKUPTARGET_DIR/$BACKUPFILE"	
		fi	
		[ ! -d "${BACKUPTARGET_DIR}" ] && mkdir -p "${BACKUPTARGET_DIR}"
		
	else
		LOG_OUTPUT=$LOG_OUTPUT_HOME
	fi

	if [[ $LOG_OUTPUT == $LOG_OUTPUT_BACKUPLOC ]]; then
		LOG_FILE="$BACKUPTARGET_LOG_FILE.log"
	elif [[ $LOG_OUTPUT == $LOG_OUTPUT_VARLOG ]]; then 
		LOG_BASE="/var/log/$MYNAME"
		[ ! -d ${LOG_BASE} ] && mkdir -p ${LOG_BASE}
		LOG_FILE="$LOG_BASE/$HOSTNAME.log"
	elif [[ $LOG_OUTPUT == $LOG_OUTPUT_HOME ]]; then
		LOG_FILE="$MYNAME.log"	
	else
		LOG_FILE="/var/log/syslog"	
	fi

	if [[ $LOG_OUTPUT != $LOG_OUTPUT_SYSLOG ]]; then	# keep syslog :-)
		rm -rf "$LOG_FILE" 2>&1 1>/dev/null
	fi

	logItem "LOG_OUTPUT: $LOG_OUTPUT"	
	logItem "Using logfile $LOG_FILE"

	if [[ -z "$LOG_FILE" || "$LOG_FILE" == *"*"* ]]; then
		abort $LINENO
	fi
	
	exec 1> >(tee -a "$LOG_FILE" >&1)
	exec 2> >(tee -a "$LOG_FILE" >&2)

	logItem "$GIT_CODEVERSION"

}

# deploy script on my local PIs

function deployMyself() { # invocationparms    
    for hostLogon in $DEPLOYMENT_HOSTS; do
		host=$(echo $hostLogon | cut -d '@' -f 2)
		user=$(echo $hostLogon | cut -d '@' -f 1)
		if ping -c 1 $host >/dev/null; then 
			echo -n "*** Deploying to $host ..."
			if [[ $user == "root" ]]; then
				scp -p $MYSELF $hostLogon:/usr/local/bin > /dev/null
			else
				scp -p $MYSELF $hostLogon:/home/$user > /dev/null
			fi
			echo " Done"
		else
			echo "??? $host offline"
		fi
    done
    exit 0
}

function sendEMail() { # content subject 

	logEntry "sendEMail"	
	
	if [ -n "$EMAIL" ]; then
		local attach
		local content
		local subject
		local latestVersion newVersion oldVersion
		local rc
		
		local attach=""
		local subject="$2"

		if (( $APPENDLOG )); then
			attach="-a $LOG_FILE"
			logItem "Appendlog $attach"
		fi
		
		if (( $NOTIFY_UPDATE && $UPDATE_POSSIBLE )); then			
				subject=";-) $subject"
		fi

		IFS=" "
		if [ -e "$LOG_MAIL_FILE" ]; then
			content="$(<"$LOG_MAIL_FILE")$NL$1" 
		else
			content="$1" 
		fi
		unset IFS
		
		logItem "Sending eMail with program $EMAIL_PROGRAM and parms '$EMAIL_PARMS'"
		logItem "Parm1:$1 Parm2:$subject"
		logItem "Content: $content"
				
		case $EMAIL_PROGRAM in
			mail) echo "$content" | "$EMAIL_PROGRAM" -s "$subject" $attach "$EMAIL"	
				;;
			sendEmail) echo "$content" | "$EMAIL_PROGRAM" $EMAIL_PARMS -u "$subject" $attach -t "$EMAIL" 
				;;
			ssmtp) 
				if (( $APPENDLOG )); then
					logItem "Sending email with mpack"
					echo "$content" > /tmp/$$
					mpack -s "$subject" -d /tmp/$$ "$LOG_FILE" "$EMAIL"
					rm /tmp/$$
				else
					logItem "Sendig email with ssmtp"
					echo -e "To: $EMAIL\nFrom: root@$(hostname -f)\nSubject: $subject\n$content" | "$EMAIL_PROGRAM" "$EMAIL"
				fi
				;;
			*) echo "??? unknown email programm $EMAIL_PROGRAM"
				exit 127
				;;
		esac				
	fi
	logExit "sendEMail"	

}

function cleanup() { # trap

	if [[ -n "$RESTOREFILE" ]]; then
		cleanupRestore $1
	else
		cleanupBackup $1
	fi

}

function cleanupRestore() {
	
	logEntry "cleanupRestore"	
	
	local error=0
	trap - SIGINT SIGTERM EXIT
	
	logItem "Got trap $1"

	rm $$.sfdisk 1>/dev/null 2>&1			
	logItem "Umount $MNT_POINT"
	umount $MNT_POINT 1>/dev/null 2>&1 
	logItem "Deleting dir $MNT_POINT"
	rmdir $MNT_POINT 1>/dev/null 2>&1 

	if [[ -z "$rc" || $rc -ne 0 ]]; then
		[ -z "$rc" ] && rc=$1
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_ERROR_OCCURED $rc
		logItem "Error occured with rc $rc"
		error=1
	fi
	
	if (( $error )); then
	 	writeToConsole $MSG_LEVEL_MINIMAL $MSG_RESTORE_FAILED "$lastTask $rc $LOG_FILE"
	else
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_RESTORE_OK
	fi

	logExit "cleanupRestore"	

}

function cleanupBackup() {

	local lastTask=$currentTask
	logEntry "cleanupBackup" 
	
	trap - SIGINT SIGTERM EXIT
	
	logItem "Got trap $1"
	
	if [[ -z "$rc" || $rc -ne 0 ]]; then
		[ -z "$rc" ] && rc=$1
	 	
		# failure - ffdc and cleanup
	
		echo "Invocation parms: '$passedOpts'" >> "$LOG_FILE"
	
		if [[ -f $ETC_CONFIG ]]; then
			echo "=== Config file start ===" >> "$LOG_FILE"
			cat $ETC_CONFIG >> "$LOG_FILE"
			echo "=== Config file end ===" >> "$LOG_FILE"
		fi
	
		if [[ -z "$BACKUPPATH" || -z "$BACKUPFILE" || "$BACKUPFILE" == *"*"* || "$BACKUPPATH" == *"*"* ]]; then
			abort $LINENO
		fi
		
	 	writeToConsole $MSG_LEVEL_MINIMAL $MSG_BACKUP_FAILED "$lastTask" "$rc" "$LOG_FILE"

		if [[ $BACKUPTYPE == $BACKUPTYPE_RSYNC ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_REMOVING_BACKUP "$BACKUPTARGET_DIR"
			rm -fr "$BACKUPTARGET_DIR" # remove incomplete backupdir if it exists		
		else
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_REMOVING_BACKUP "$BACKUPTARGET_FILE"
			rm -fr "$BACKUPTARGET_FILE" # remove incomplete backupfile if it exists
		fi

		msg=$(getLocalizedMessage $MSG_BACKUP_FAILED "$lastTask" "$rc" "$LOG_FILE")
		msgTitle=$(getLocalizedMessage $MSG_TITLE_ERROR $HOSTNAME)
		logItem "emailTitle: $msgTitle"
		[ -n "$EMAIL" ] && sendEMail "$msg" "$msgTitle"

	else
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_BACKUP_OK 
		msg=$(getLocalizedMessage $MSG_TITLE_OK $HOSTNAME)
		logItem "emailTitle: $msg"
		[ -n "$EMAIL" ] && sendEMail "" "$msg"
	fi
	
	cleanupTempFiles
		
	logExit  "cleanupBackup"	

}

function cleanupTempFiles() {
	
	if [[ -f "$LOG_MAIL_FILE" ]]; then
		logItem "Removing mailfile $LOG_MAIL_FILE"
		rm -f "$LOG_MAIL_FILE" 1>/dev/null 2>&1 
	fi
	
	if [[ -f $LATEST_VERSION_FILE ]]; then
		logItem "Removing versionfile $LATEST_VERSION_FILE"	
		rm -f $LATEST_VERSION_FILE 1>/dev/null 2>&1 
	fi

	if [[ -f $MYSELF~ ]]; then
		logItem "Removing newversion $MYNAME~"
		rm -f $MYNAME~ 1>/dev/null 2>&1 
	fi

}

function checkAndCorrectImportantParameters() {

		local invalidOutput=""
		local invalidLanguage=""
		local invalidLogLevel=""
		local invalidMsgLevel=""
		
		if [[ $LOG_OUTPUT < 0 || $LOG_OUTPUT > ${#LOG_OUTPUT_LOCs[@]} ]]; then
			invalidOutput=$LOG_OUTPUT
			LOG_OUTPUT=$LOG_OUTPUT_SYSLOG			
		fi

		if [[ $MSG_LEVEL < 0 || $MSG_LEVEL > ${#MSG_LEVELs[@]} ]]; then
			invalidMsgLevel=$MSG_LEVEL
			MSG_LEVEL=$MSG_LEVEL_MINIMAL
		fi
	
		local msgVar="MSG_${LANGUAGE}"
		if [[ -z ${!msgVar} ]]; then
			invalidLanguage=$LANGUAGE
			LANGUAGE="EN"
		fi

		if [[ $LOG_LEVEL < 0 || $LOG_LEVEL > ${#LOG_LEVELs[@]} ]]; then
			invalidLogLevel=$LOG_LEVEL
			LOG_LEVEL=$LOG_TYPE_MSG
		fi

		[[ -n $invalidOutput ]] && writeToConsole $MSG_LEVEL_MINIMAL $MSG_INVALID_LOG_OUTPUT "$invalidOutput" $LOG_OUTPUT		
		[[ -n $invalidMsgLevel ]] && writeToConsole $MSG_LEVEL_MINIMAL $MSG_INVALID_MSG_LEVEL "$invalidMsgLevel" $MSG_LEVEL
		[[ -n $invalidLanguage ]] && writeToConsole $MSG_LEVEL_MINIMAL $MSG_LANGUAGE_NOT_SUPPORTED "$invalidLanguage" $LANGUAGE
		[[ -n $invalidLogLevel ]] && writeToConsole $MSG_LEVEL_MINIMAL $MSG_INVALID_LOG_LEVEL "$invalidLogLevel" $LOG_LEVEL

		logExit "checkAndCorrectImportantParameters"
	
}

function bootPartitionBackup() {
	
		local p
		
		logEntry  "bootPartitionBackup"	
		logItem "Starting boot partition backup..."	

		if (( ! $FAKE && ! $EXCLUDE_DD )); then
			if  [[ ! -e "$BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.img" ]]; then
				writeToConsole $MSG_LEVEL_DETAILED $MSG_CREATING_BOOT_BACKUP "$BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.img"
				(( $NOS )) && p=5 || p=1
				dd if=/dev/mmcblk0p${p} of="$BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.img" bs=1M > /dev/null 2>&1
			else
				logItem "Found existing backup of boot partition $BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.img ..."
				writeToConsole $MSG_LEVEL_DETAILED $MSG_EXISTING_BOOT_BACKUP "$BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.img"
			fi
		
			if  [[ ! -e "$BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.sfdisk" ]]; then
				writeToConsole $MSG_LEVEL_DETAILED $MSG_CREATING_PARTITION_BACKUP "$BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.sfdisk"
				sfdisk -d /dev/mmcblk0 > "$BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.sfdisk"
			
				logItem "sfdisk"				
				logItem $(cat "$BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.sfdisk")

			else
				logItem "Found existing backup of partition layout $BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.sfdisk ..."
				writeToConsole $MSG_LEVEL_DETAILED $MSG_EXISTING_PARTITION_BACKUP "$BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.sfdisk"
			fi
			
			if  [[ ! -e "$BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.mbr" ]]; then
				writeToConsole $MSG_LEVEL_DETAILED $MSG_CREATING_MBR_BACKUP "$BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.mbr"
				dd if=/dev/mmcblk0 of="$BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.mbr" bs=512 count=1 1>/dev/null 2>&1
			else
				logItem "Found existing backup of master boot record $BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.mbr ..."
				writeToConsole $MSG_LEVEL_DETAILED $MSG_EXISTING_MBR_BACKUP "$BACKUPTARGET_ROOT/$BACKUPFILE_NODATE.mbr"
			fi
		fi

		logItem "Finished boot partition backup..."	
		
		logExit  "bootPartitionBackup"	
				
}		

function ddBackup() {

	logEntry  "ddBackup"	

	local cmd verbose

	(( $VERBOSE )) && verbose="-v" || verbose=""

	if [[ $BACKUPTYPE == $BACKUPTYPE_DDZ ]]; then
		cmd="dd if=/dev/mmcblk0 bs=$DD_BLOCKSIZE $DD_PARMS | gzip ${verbose} > \"$BACKUPTARGET_FILE\""
	else
		cmd="dd if=/dev/mmcblk0 bs=$DD_BLOCKSIZE $DD_PARMS of=\"$BACKUPTARGET_FILE\""
	fi	

	logItem "$cmd"

	if (( ! $EXCLUDE_DD )); then
		if (( ! $FAKE)); then
			writeToConsole $MSG_LEVEL_DETAILED $MSG_BACKUP_STARTED "$BACKUPTYPE"
			executeCommand "$cmd"
			rc=$?
		else
			rc=0
		fi
	fi

	if (( $FORCED_RC )); then
		rc=$FORCED_RC
	fi

	logExit  "ddBackup"	

	return $rc
}

function tarBackup() {
	local verbose zip cmd

	logEntry  "tarBackup"	
	
	(( $VERBOSE )) && verbose="v" || verbose=""
	[[ $BACKUPTYPE == $BACKUPTYPE_TGZ ]] && zip="z" || zip=""
	bootPartitionBackup

	[ -n "$EXCLUDE_LIST" ] && EXCLUDE_LIST="\"$EXCLUDE_LIST\""

	cmd="tar -cp${zip}i${verbose} --one-file-system -f \"$BACKUPTARGET_FILE\" \
			--exclude=\"$BACKUPPATH_PARAMETER\" \
			--exclude=/proc/* \
			--exclude=/lost+found/* \
			--exclude=/sys/* \
			--exclude=/dev/* \
			--exclude=/tmp/* \
			--exclude=/boot/* \
			--exclude=/run/* \
			--warning=no-xdev \
			$EXCLUDE_LIST \
			\"$DIR_TO_BACKUP\""

	logItem "$cmd"

	if (( !$FAKE )); then
		writeToConsole $MSG_LEVEL_DETAILED $MSG_BACKUP_STARTED "$BACKUPTYPE"
		executeCommand "$cmd"
	else
		rc=0
	fi

	if (( $FORCED_RC )); then
		rc=$FORCED_RC
	fi

	if [[ $rc -eq 1 ]]; then		# some files changed during backup or vanished during backup
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_FILES_CHANGE_DURING_BACKUP $rc
		rc=0
	fi

	logExit  "tarBackup"	

	return $rc
}

function xbmcBackup() {
	local verbose cmd

	logEntry "xbmcBackup"	
	
	(( $VERBOSE )) && verbose="v" || verbose=""
	bootPartitionBackup
	
	cmd="tar -cpz$verbose --one-file-system -f \"$BACKUPTARGET_FILE\" \
				--exclude=\"$BACKUPPATH_PARAMETER\" \
				--warning=no-xdev \
				/home/pi/.xbmc"

	logItem "$cmd"

	if (( !$FAKE )); then
		writeToConsole $MSG_LEVEL_DETAILED $MSG_BACKUP_STARTED "$BACKUPTYPE"
		eval "$cmd"
		rc=$?
	else
		rc=0
	fi

	if (( $FORCED_RC )); then
		rc=$FORCED_RC
	fi
	
	logExit "xbmcBackup"	
	
	return $rc
}

function rsyncBackup() {
	local rc verbose

	logEntry  "rsyncBackup"	
	
	(( $VERBOSE )) && verbose="v" || verbose=""
	bootPartitionBackup
	lastBackupDir=$(find "$BACKUPTARGET_ROOT" -maxdepth 1 -name "*-$BACKUPTYPE-*" | sort -r | head -n 2 | tail -n 1)

	logItem "LastBackupDir: $lastBackupDir"
	
	if  [[ -z "$lastBackupDir" || ! (( $HARDLINKS )) ]]; then
		LINK_DEST=""
	else
		LINK_DEST="--link-dest=\"$lastBackupDir\""
	fi
	
	logItem "LinkDest: $LINK_DEST"

	[ -n "$EXCLUDE_LIST" ] && EXCLUDE_LIST="\"$EXCLUDE_LIST\""

	cmd="rsync --exclude=\"$BACKUPPATH_PARAMETER\" \
			--exclude=/proc/* \
			--exclude=/lost+found/* \
			--exclude=/sys/* \
			--exclude=/dev/* \
			--exclude=/boot/* \
			--exclude=/tmp/* \
			--exclude=/run/* \
			$EXCLUDE_LIST \
			$LINK_DEST \
			--numeric-ids \
			-aHAXx$verbose \
			\"$DIR_TO_BACKUP\" \"$BACKUPTARGET_DIR\"
"
	logItem "$cmd"
	
	if (( ! $FAKE )); then
		writeToConsole $MSG_LEVEL_DETAILED $MSG_BACKUP_STARTED "$BACKUPTYPE"
		executeCommand "$cmd"
	else
		rc=0
	fi

	if (( $FORCED_RC )); then
		rc=$FORCED_RC
	fi
		
	if [[ $rc -eq 23 || $rc -eq 24 ]]; then		# some files changed during backup or vanished during backup
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_FILES_CHANGE_DURING_BACKUP $rc
		rc=0
	fi

	logExit  "rsyncBackup"	
	
}

function restore() {

	logEntry "restore"	

	rc=0
	local verbose zip
	
	(( $VERBOSE )) && verbose="v" || verbose=""

	trapWithArg cleanup SIGINT SIGTERM EXIT

	writeToConsole $MSG_LEVEL_MINIMAL $MSG_STARTED "$HOSTNAME" "$MYSELF" "$VERSION" "$(date)"

	writeToConsole $MSG_LEVEL_DETAILED $MSG_RESTORING_FILE "$RESTOREFILE"	
		
	rc=""
	
	case $BACKUPTYPE in
		
		$BACKUPTYPE_DD|$BACKUPTYPE_DDZ) 
			if [[ $BACKUPTYPE == $BACKUPTYPE_DD ]]; then
				cmd="dd of=$RESTORE_DEVICE bs=$DD_BLOCKSIZE if=\"$RESTOREFILE\" $DD_PARMS" 
			else
				cmd="gunzip -c if=\"$RESTOREFILE\" | dd of=$RESTORE_DEVICE bs=$DD_BLOCKSIZE $DD_PARMS" 
			fi
			
			logItem "$cmd"
			executeCommand "$cmd"
			rc=$?
			;;

		$BACKUPTYPE_XBMC) 
			cd /home/pi/.xbmc; 
			cmd="tar -xzf \"$RESTOREFILE\"; cd -"
			logItem "$cmd"
			executeCommand "$cmd"
			rc=$?
			;;
	
		*)

			MNT_POINT="/media/${MYNAME}"
		
			if ( isMounted "$MNT_POINT" ); then
				logItem "$MNT_POINT mounted - unmouting"
				umount "$MNT_POINT"
			fi

			logItem "Creating mountpoint $MNT_POINT"
			mkdir -p $MNT_POINT

			logItem "Unmounting partitions"
			umount $BOOT_PARTITION 1>/dev/null 2>&1 
			umount $ROOT_PARTITION 1>/dev/null 2>&1 

			writeToConsole $MSG_LEVEL_DETAILED $MSG_RESTORING_MBR "$MBR_FILE" "$RESTORE_DEVICE"
			dd of=$RESTORE_DEVICE if="$MBR_FILE" count=1 

			writeToConsole $MSG_LEVEL_DETAILED $MSG_CREATING_PARTITIONS
			awk '/mmcblk0p1/ { no2=substr($6,1,length($6)-1); res=$4 no2; print res ",c"; } { next; }' "$SF_FILE" > $$.sfdisk
			awk '/mmcblk0p2/ { res=substr($4,1,length($4)-1); print res; } { next; }' "$SF_FILE" >> $$.sfdisk
			
			logItem ".sfdisk: $(cat $$.sfdisk)"
			sfdisk --force -uSL $RESTORE_DEVICE < $$.sfdisk
			partprobe $RESTORE_DEVICE
			rm $$.sfdisk

			writeToConsole $MSG_LEVEL_DETAILED $MSG_RESTORING_FIRST_PARTITION "$BOOT_PARTITION"
			dd of=$BOOT_PARTITION if="$DD_FILE" bs=1M

			writeToConsole $MSG_LEVEL_DETAILED $MSG_FORMATTING_SECOND_PARTITION "$ROOT_PARTITION"
			mkfs.ext4 $ROOT_PARTITION
	
			writeToConsole $MSG_LEVEL_DETAILED $MSG_RESTORING_SECOND_PARTITION "$ROOT_PARTITION"
			mount $ROOT_PARTITION "$MNT_POINT"

			case $BACKUPTYPE in

				$BACKUPTYPE_TAR|$BACKUPTYPE_TGZ)
					cd "$MNT_POINT"
					[[ $BACKUPTYPE == $BACKUPTYPE_TGZ ]] && zip="z" || zip=""
					cmd="tar -x${verbose}${zip}f \"$RESTOREFILE\"; cd -"
					logItem "$cmd"
					executeCommand "$cmd"
					rc=$?
					;;
									
				$BACKUPTYPE_RSYNC) 
					cmd="rsync -aHX$verbose \"$RESTOREFILE/\" $MNT_POINT"
					logItem "$cmd"
					executeCommand "$cmd"
					rc=$?
					;;
	 
				*) echo "??? Invalid backuptype $BACKUPTYPE"
					exit 127;;			
			esac
			
			logItem "parted $RESTORE_DEVICE print"
			logItem "$(parted $RESTORE_DEVICE print)"
			
			if [[ $RESTORE_DEVICE = "/dev/mmcblk0" || $RESTORE_DEVICE = "/dev/loop0" ]]; then
				ROOT_DEVICE=$(sed -E 's/p[0-9]+$//' <<< $ROOT_PARTITION)
			else
				ROOT_DEVICE=$(sed -E 's/[0-9]+$//' <<< $ROOT_PARTITION)
			fi
			
			if [[ $ROOT_DEVICE != $RESTORE_DEVICE ]]; then
				logItem "parted $ROOT_DEVICE print"
				logItem "$(parted $ROOT_DEVICE print)"
			fi

	esac

	logItem "Syncing filesystems"
	sync
	umount $MNT_POINT 1>/dev/null 2>&1 
		
	writeToConsole $MSG_LEVEL_DETAILED $MSG_RESTORING_FILE_DONE
	
	logExit "restore"	
	
}

function backup() {

	logEntry "backup"	

	logger -t $MYSELF "Starting backup..."	

	writeToConsole $MSG_LEVEL_MINIMAL $MSG_STARTED "$HOSTNAME" "$MYSELF" "$VERSION" "$(date)"
	
	trapWithArg cleanup SIGINT SIGTERM EXIT

	stopServices
	callExtensions $PRE_BACKUP_EXTENSION "0"

	BACKUPPATH_PARAMETER="$BACKUPPATH"
	BACKUPPATH="$BACKUPPATH/$HOSTNAME"
	if [[ ! -d "$BACKUPPATH" ]]; then
		mkdir -p "$BACKUPPATH"		
	fi

	if [[ $BACKUPTYPE == $BACKUPTYPE_RSYNC ]]; then
		writeToConsole $MSG_LEVEL_DETAILED $MSG_BACKUP_TARGET "$BACKUPTYPE" "$BACKUPTARGET_DIR" 
	else
		writeToConsole $MSG_LEVEL_DETAILED $MSG_BACKUP_TARGET "$BACKUPTYPE" "$BACKUPTARGET_FILE"
	fi
		
	logItem "Storing backup in backuppath $BACKUPPATH"

	logItem "fdisk -l /dev/mmcblk0"
	logItem "$(fdisk -l /dev/mmcblk0)"

	logItem "Starting $BACKUPTYPE backup..."	

	rc=0
	
	case "$BACKUPTYPE" in
	
		$BACKUPTYPE_DD|$BACKUPTYPE_DDZ) ddBackup
			;;
	
		$BACKUPTYPE_TAR|$BACKUPTYPE_TGZ) tarBackup
			;;
			
		$BACKUPTYPE_XBMC) xbmcBackup
			;;
			
		$BACKUPTYPE_RSYNC) rsyncBackup
			;;
		 
		*) echo "??? Invalid backuptype $BACKUPTYPE"
			exit 127;;			
	esac
	rc=$?

	logItem "Finished $BACKUPTYPE backup"	

	logItem "Backup created with return code: $rc"
	
	if [[ $rc -eq 0 ]]; then	
		logItem "Deleting oldest directory in $BACKUPPATH"
		logItem "Current directory: $(pwd)"	
		if [[ -z "$BACKUPPATH" || "$BACKUPPATH" == *"*"* ]]; then
			abort $LINENO
		fi
		logItem "BackupType: $BACKUPTYPE"
		if (( ! $FAKE )); then
			pushd "$BACKUPPATH" 1>/dev/null; ls -d *-$BACKUPTYPE-* | grep -v ".log$" | head -n -$KEEPBACKUPS | xargs -I {} rm -rf$verbose "{}" 2>/dev/null ; popd > /dev/null
			pushd "$BACKUPPATH" 1>/dev/null; ls -d *-$BACKUPTYPE-* | grep ".log$" | head -n -$KEEPBACKUPS | xargs -I {} rm -rf$verbose "{}" 2>/dev/null ; popd > /dev/null
		fi
	fi
	
	callExtensions $POST_BACKUP_EXTENSION $rc
	startServices
	
	writeToConsole $MSG_LEVEL_MINIMAL $MSG_STOPPED "$HOSTNAME" "$MYSELF" "$VERSION" "$(date)"

	logger -t $MYSELF "Backup finished"	
	logExit "backup"	

}

function doit() {

	local msg
	logEntry "doit"	
	logItem "Startingdirectory: $(pwd)"	
	logItem "$(fdisk -l 2>/dev/null)"

	if [[ -n "$RESTOREFILE" ]]; then
		doitRestore
	else
		doitBackup
	fi
	
	logItem "Enddirectory: $(pwd)"	

	logExit "doit"	

}

function doitBackup() {

	logEntry "doitBackup"

	logItem "NOS: $NOS - EXCLUDE_DD: $EXCLUDE_DD"

	if (( ! $NOS && ! $EXCLUDE_DD )); then
		if ! fdisk -l /dev/mmcblk0 | grep "/dev/mmcblk0p1" > /dev/null; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_NO_BOOT_PARTITION
			exit 127
		fi
		if [[ $(fdisk -l /dev/mmcblk0 | grep "/dev/mmcblk0p" | wc -l) -gt 2 && "$BACKUPTYPE" != "$BACKUPTYPE_DD" && "$BACKUPTYPE" != "$BACKUPTYPE_DDZ" ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_MULTIPLE_PARTITIONS_FOUND
			exit 127
		fi
	fi
	
	if [[ -n "$EMAIL" ]]; then
		regex="^(mail|sendEmail|ssmtp)$"
		if [[ ! $EMAIL_PROGRAM =~ $regex ]]; then
			supportedMails=$(echo $regex | sed 's:^..\(.*\)..$:\1:')
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_EMAIL_PROG_NOT_SUPPORTED "$EMAIL_PROGRAM" "$supportedMails"
			exit 127
		fi
		if [[ ! $(which $EMAIL_PROGRAM) ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_MAILPROGRAM_NOT_INSTALLED $MAIL_PROGRAM
			exit 127
		fi
		if [[ "$MAIL_PROGRAM" == "ssmtp" && (( $APPENDLOG )) ]]; then
			if [[ ! $(which mpack) ]]; then
				writeToConsole $MSG_LEVEL_MINIMAL $MSG_MPACK_NOT_INSTALLED 
				exit 127
			fi
		fi
		
	fi
	
	if [[ "${BACKUPPATH:0:1}" != "/" ]]; then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_BACKUPPATH_HASTOBEABSOLUTE "$BACKUPPATH"
		exit 127
	fi

	BACKUPPATH=$(sed -E 's@/+$@@g' <<< "$BACKUPPATH")

	if [[ ! -d "$BACKUPPATH" ]]; then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_BACKUPPATH_DOESNOTEXIST "$BACKUPPATH"
		exit 127
	fi

	if ! touch "$BACKUPPATH/$MYNAME.tmp"; then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_UNABLE_TO_WRITE "$BACKUPPATH"
		exit 127
	else
		rm -f "$BACKUPPATH/$MYNAME.tmp" &>/dev/null
	fi

	if (( ! $SKIPLOCALCHECK )) && ! isMounted "$BACKUPPATH"; then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_NO_DEVICEMOUNTED "$BACKUPPATH"
		exit 127
	fi

	if [[ "$BACKUPTYPE" != "xbmc" ]]; then
		if [[ "${DIR_TO_BACKUP:0:1}" != "/" ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_DIR_TO_BACKUP_ABSOLUTE "$DIR_TO_BACKUP"
			exit 127
		fi

		if [[ ! -d "$DIR_TO_BACKUP" ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_DIR_TO_BACKUP_DOESNOTEXIST "$DIR_TO_BACKUP"
			exit 127
		fi
	else
		if [[ ! -d "/home/pi/.xbmc" ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_DIR_TO_BACKUP_DOESNOTEXIST "/home/pi/.xbmc"			
			exit 127
		fi
	fi

	regex="^[0-9]+$"
	if [[ ! $KEEPBACKUPS =~ $regex || $KEEPBACKUPS -lt 1 || $KEEPBACKUPS -gt 365 ]]; then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_KEEPBACKUP_INVALID $KEEPBACKUPS
		mentionHelp
		exit 127
	fi

	if (( $ZIP_BACKUP_TYPE_INVALID )); then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_UNKNOWN_BACKUPTYPE_FOR_ZIP $BACKUPTYPE
		mentionHelp
		exit 127
	fi

	regex="^(${POSSIBLE_TYPES})$"
	if [[ ! $BACKUPTYPE =~ $regex ]]; then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_UNKNOWN_BACKUPTYPE $BACKUPTYPE
		mentionHelp
		exit 127
	fi

	if [[ $BACKUPTYPE == $BACKUPTYPE_RSYNC ]]; then
		if [[ ! $(which rsync) ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_RSYNC_NOT_INSTALLED 
			exit 127
		fi
		if (( $HARDLINKS )); then
			if ! df -hT "$BACKUPPATH" | grep -viE "Filesystem" | awk '{print $2}' | egrep "ext[34]|nfs|tmpfs" > /dev/null; then
				writeToConsole $MSG_LEVEL_MINIMAL $MSG_FILESYSTEM_INCORRECT "$BACKUPPATH"
				exit 127
			fi
		fi
	fi

	backup

	logExit "doitBackup"

}

function doitRestore() {

	logEntry "doitRestore"		

	if [[ ! -d "$RESTOREFILE" && ! -f "$RESTOREFILE" ]]; then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_FILE_NOT_FOUND "$RESTOREFILE"
		exit 127
	fi

	if [[ "${RESTOREFILE:0:1}" != "/" ]]; then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_RESTOREFILE_ABSOLUTE "$RESTOREFILE"
		exit 127
	fi
	
	regex=""
	for type in $POSSIBLE_TYPES; do
		[[ -z $regex ]] && regex="$type" || regex="$regex|$type"
	done
	regex="\-($regex)\-backup\-"
	
	if [[ ! $(basename "$RESTOREFILE") =~ $regex ]]; then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_RESTORE_FILE_INVALID "$RESTOREFILE"
		exit 127
	fi	

	if [[ -z $RESTORE_DEVICE ]]; then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_NO_RESTOREDEVICE_DEFINED
		exit 127
	fi	
	
	if [[ $RESTORE_DEVICE != "/dev/mmcblk0" && $RESTORE_DEVICE != "/dev/loop0" ]]; then
		local re='^/dev/[a-zA-Z]+$'
		if ! [[ "$RESTORE_DEVICE" =~ $re ]] ; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_RESTOREDEVICE_IS_PARTITION
			exit 127
		fi			
	fi
	
	if [[ -z $(fdisk -l $RESTORE_DEVICE) ]]; then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_NO_RESTOREDEVICE_FOUND $RESTORE_DEVICE
		exit 127
	fi	
		
	BASE_DIR=$(dirname "$RESTOREFILE")
	logItem "Basedir: $BASE_DIR"
	HOSTNAME=$(basename "$RESTOREFILE" | sed -r 's/(.*)-[A-Za-z]+-backup-[0-9]+-[0-9]+.*/\1/')
	logItem "Hostname: $HOSTNAME"
	BACKUPTYPE=$(basename "$RESTOREFILE" | sed -r 's/.*-([A-Za-z]+)-backup-[0-9]+-[0-9]+.*/\1/')

	logItem "Backuptype: $BACKUPTYPE"

	DD_FILE="$BASE_DIR/$HOSTNAME-backup.img"
	logItem "DD_FILE: $DD_FILE"
	SF_FILE="$BASE_DIR/$HOSTNAME-backup.sfdisk"
	logItem "SF_FILE: $SF_FILE"
	MBR_FILE="$BASE_DIR/$HOSTNAME-backup.mbr"
	logItem "MBR_FILE: $MBR_FILE"

	if [[ "$BACKUPTYPE" != $BACKUPTYPE_DD && "$BACKUPTYPE" != $BACKUPTYPE_DDZ ]]; then 
		if [[ ! -e "$SF_FILE" ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_FILE_NOT_FOUND "$SF_FILE"
			exit 127
		fi
		if [[ ! -e "$DD_FILE" ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_FILE_NOT_FOUND "$DD_FILE"
			exit 127
		fi
		if [[ ! -e "$MBR_FILE" ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_FILE_NOT_FOUND "$MBR_FILE"
			exit 127
		fi
	fi

	if [[ $RESTORE_DEVICE = "/dev/mmcblk0" || $RESTORE_DEVICE = "/dev/loop0" ]]; then
		BOOT_PARTITION="${RESTORE_DEVICE}p1"
	else
		BOOT_PARTITION="${RESTORE_DEVICE}1"
	fi
	logItem "BOOT_PARTITION : $BOOT_PARTITION"

	ROOT_PARTITION_DEFINED=1
	if [[ -z $ROOT_PARTITION ]]; then
		if [[ $RESTORE_DEVICE = "/dev/mmcblk0" || $RESTORE_DEVICE = "/dev/loop0" ]]; then
			ROOT_PARTITION="${RESTORE_DEVICE}p2"
		else
			ROOT_PARTITION="${RESTORE_DEVICE}2"
		fi
		ROOT_PARTITION_DEFINED=0
	else
		if [[ ! -e "$ROOT_PARTITION" ]]; then
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_ROOT_PARTTITION_NOT_FOUND $ROOT_PARTITION
			exit 127
		fi
	fi			

	logItem "ROOT_PARTITION : $ROOT_PARTITION"
	current_partition_table="$(parted $RESTORE_DEVICE print)"
	writeToConsole $MSG_LEVEL_MINIMAL $MSG_REPARTITION_WARNING $RESTORE_DEVICE 
	writeToConsole $MSG_LEVEL_MINIMAL $MSG_CURRENT_PARTITION_TABLE "$RESTORE_DEVICE" "$current_partition_table"
	
	if (( ! $ROOT_PARTITION_DEFINED )); then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_WARN_RESTORE_DEVICE_OVERWRITTEN $RESTORE_DEVICE
	else
		if [[ $ROOT_DEVICE = "/dev/mmcblk0" || $ROOT_DEVICE = "/dev/loop0" ]]; then
			ROOT_DEVICE=$(sed -E 's/p[0-9]+$//' <<< $ROOT_PARTITION)
		else
			ROOT_DEVICE=$(sed -E 's/[0-9]+$//' <<< $ROOT_PARTITION)
		fi
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_CURRENT_PARTITION $ROOT_DEVICE
		current_partition_table="$(parted $ROOT_DEVICE print)"
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_CURRENT_PARTITION_TABLE "$ROOT_DEVICE" "$current_partition_table"
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_WARN_BOOT_PARTITION_OVERWRITTEN $BOOT_PARTITION
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_WARN_ROOT_PARTITION_OVERWRITTEN $ROOT_PARTITION
	fi
	
    yes_no=$(getLocalizedMessage $MSG_QUERY_CHARS_YES_NO)

	writeToConsole $MSG_LEVEL_MINIMAL $MSG_ANSWER_YES_NO "$yes_no"
	
	read answer
	answer=${answer:0:1}	# first char only
	answer=${answer:-"n"}	# set default no
   	yes=$(getLocalizedMessage $MSG_ANSWER_CHARS_YES)
	if [[ ! $yes =~ $answer ]]; then
		exit 127
	fi
	
	restore

	logExit "doitRestore"		

}

function usageEN() {

    echo "$GIT_CODEVERSION"
    echo "usage: $MYSELF parms"
    echo ""
    echo "-General parms-"
    echo "-A append logfile to eMail (default: ${NO_YES[$DEFAULT_APPEND_LOG]})"
    [ -z "$DEFAULT_EMAIL" ] && DEFAULT_EMAIL="no" 
    echo "-b {dd block size} (default: $DEFAULT_DD_BLOCKSIZE)"
    [ -z "$DEFAULT_DD_PARMS" ] && DEFAULT_DD_PARMS="no" 
    echo "-D {additional dd parameters} (default: $DEFAULT_DD_PARMS)"
    echo "-e {email address} (default: $DEFAULT_EMAIL)"
    [ -z "$DEFAULT_EMAIL_PARMS" ] && DEFAULT_EMAIL_PARMS="no" 
    echo "-E {additional email call parameters} (default: $DEFAULT_EMAIL_PARMS)"
    echo "-G {message language} (default: $DEFAULT_LANGUAGE)"
    echo "-h display this help text"
    echo "-l {log level} ($POSSIBLE_LOG_LEVELs) (default: ${LOG_LEVELs[$DEFAULT_LOG_LEVEL]})"
    echo "-L {log location} ($POSSIBLE_LOG_LOCs) (default: ${LOG_OUTPUT_LOCs[$DEFAULT_LOG_OUTPUT]})"
    echo "-m {message level} ($POSSIBLE_MSG_LEVELs) (default: ${MSG_LEVELs[$DEFAULT_MSG_LEVEL]})"
    echo "-n Notification if there is a newer scriptversion available for download (default: ${NO_YES[$DEFAULT_NOTIFY_UPDATE]})"
    echo "-s {email program to use} (mail|sendEmail|ssmtp) (default: $DEFAULT_MAIL_PROGRAM)" 
    echo "-u {excludeList} List of directories to exclude from tar and rsync backup"
    echo "-U Die aktuelle Scriptversion wird durch eine aktuelle Version ersetzt sofern eine neuere Version existiert. Die alte Version wird gesichert"
    echo "-v verbose output of backup tools (default: ${NO_YES[$DEFAULT_VEBOSE]})"
    echo "-z compress backup file with gzip (default: ${NO_YES[$DEFAULT_ZIP_BACKUP]})"
	echo ""
    echo "-Backup parms-"
    [ -z "$DEFAULT_STOPSERVICES" ] && DEFAULT_STOPSERVICES="no" 
    echo "-a {commandsToExecuteBeforeBackup} (default: $DEFAULT_STOPSERVICES)"
    echo "-k {backupsToKeep} (default: $DEFAULT_KEEPBACKUPS)"
    [ -z "$DEFAULT_STARTSERVICES" ] && DEFAULT_STARTSERVICES="no" 
    echo "-o {commandsToExecuteAfterBackup} (default: $DEFAULT_STARTSERVICES)"
    echo "-p {backupPath} (default: $DEFAULT_BACKUPPATH)"
    echo "-t {backupType} ($ALLOWED_TYPES) (default: $DEFAULT_BACKUPTYPE)"
    if (( $EXTENDED )); then
		echo "-Restore parms-"
		[ -z "$DEFAULT_RESTORE_DEVICE" ] && DEFAULT_RESTORE_DEVICE="no" 
		echo "-d {restoreDevice} (default: $DEFAULT_RESTORE_DEVICE) (Example: /dev/sda)"
		echo "-R {rootPartition} (default: restoreDevice) (Example: /dev/sdb1)"
		echo "-r {backupDirectory or backupFile} (Default: no)"
	fi
}       

function usageDE() {

    echo "$GIT_CODEVERSION"
    echo "Aufruf: $MYSELF Parameter"
    echo ""
    echo "-Allgemeine Parameter-"
    echo "-A Logfile wird in eMail angehängt (Standard: ${NO_YES[$DEFAULT_APPEND_LOG]})"
    [ -z "$DEFAULT_EMAIL" ] && DEFAULT_EMAIL="nein" 
    echo "-b {dd Blockgröße} (Standard: $DEFAULT_DD_BLOCKSIZE)"
    [ -z "$DEFAULT_DD_PARMS" ] && DEFAULT_DD_PARMS="nein" 
    echo "-D {Zusätzliche dd Parameter} (Standard: $DEFAULT_DD_PARMS)"
    echo "-e {eMail Addresse} (Standard: $DEFAULT_EMAIL)"
    [ -z "$DEFAULT_EMAIL_PARMS" ] && DEFAULT_EMAIL_PARMS="nein" 
    echo "-E {Zusätzliche eMail Aufrufparameter} (Standard: $DEFAULT_EMAIL_PARMS)"
    echo "-G {message language} (default: $DEFAULT_LANGUAGE)"
    echo "-h Anzeige diese Hilfstextes"
    echo "-l {log Genauigkeit} ($POSSIBLE_LOG_LEVELs) (Standard: ${LOG_LEVELs[$DEFAULT_LOG_LEVEL]})"
    echo "-L {log Ausgabeort} ($POSSIBLE_LOG_LOCs) (Standard: ${LOG_OUTPUT_LOCs[$DEFAULT_LOG_OUTPUT]})"
    echo "-m {Meldungsgenauigkeit} ($POSSIBLE_MSG_LEVELs) (Standard: ${MSG_LEVELs[$DEFAULT_MSG_LEVEL]})"
    echo "-n Benachrichtigung wenn eine aktuellere Scriptversion zum download verfügbar ist. (Standard: ${NO_YES[$DEFAULT_NOTIFY_UPDATE]})"
    echo "-s {benutztes eMail Program} (mail|sendEmail|ssmtp) (Standard: $DEFAULT_MAIL_PROGRAM)" 
    echo "-u {excludeList} Liste von Verzeichnissen, die vom tar und rsync Backup auszunehmen sind"
    echo "-U Update current script version if there exists a new version. The old version will be saved"
    echo "-v Detailierte Ausgaben der Backup Tools (Standard: ${NO_YES[$DEFAULT_VEBOSE]})"
    echo "-z Backup verkleinern mit gzip (Standard: ${NO_YES[$DEFAULT_ZIP_BACKUP]})"
	echo ""
    echo "-Backup Parameter-"
    [ -z "$DEFAULT_STOPSERVICES" ] && DEFAULT_STOPSERVICES="keine" 
    echo "-a {BefehleDieVorDemBackupAusgeführtWerden} (Standard: $DEFAULT_STOPSERVICES)"
    echo "-k {Anzahl Backups} (Standard: $DEFAULT_KEEPBACKUPS)"
    [ -z "$DEFAULT_STARTSERVICES" ] && DEFAULT_STARTSERVICES="keine" 
    echo "-o {BefehleDieNachDemBackupAusgeführtWerden} (Standard: $DEFAULT_STARTSERVICES)"
    echo "-p {Backuppfad} (Standard: $DEFAULT_BACKUPPATH)"
    echo "-t {Backuptyp} ($ALLOWED_TYPES) (Standard: $DEFAULT_BACKUPTYPE)"
    if (( $EXTENDED )); then
		echo "-Restore Parameter-"
		[ -z "$DEFAULT_RESTORE_DEVICE" ] && DEFAULT_RESTORE_DEVICE="keiner" 
		echo "-d {restoreGerät} (Standard: $DEFAULT_RESTORE_DEVICE) (Beispiel: /dev/sda)"
		echo "-R {rootPartition} (Standard: restoreDevice) (Beispiel: /dev/sdb1)"
		echo "-r {Backupverzeichnis oder -datei} (Standard: keiner)"
	fi
}       

function mentionHelp() {
	writeToConsole $MSG_LEVEL_MINIMAL $MSG_MENTION_HELP $MYSELF
}

##### Now do your job

passedOpts="$@"				# save passed opts for logging

readConfigParameters		# overwrite defaults from config files

# setup defaults for parameters
# 0 is false, true otherwise

BACKUPPATH="$DEFAULT_BACKUPPATH"
KEEPBACKUPS=$DEFAULT_KEEPBACKUPS
BACKUPTYPE=$DEFAULT_BACKUPTYPE
STOPSERVICES=$DEFAULT_STOPSERVICES
STARTSERVICES=$DEFAULT_STARTSERVICES
EMAIL=$DEFAULT_EMAIL
EMAIL_PROGRAM=$DEFAULT_MAIL_PROGRAM
EMAIL_PARMS=$DEFAULT_EMAIL_PARMS
LOG_LEVEL=$DEFAULT_LOG_LEVEL
MSG_LEVEL=$DEFAULT_MSG_LEVEL
VERBOSE=$DEFAULT_VEBOSE
RESTORE_DEVICE=$DEFAULT_RESTORE_DEVICE
APPENDLOG=$DEFAULT_APPEND_LOG
LOG_OUTPUT=$DEFAULT_LOG_OUTPUT
HARDLINKS=1
SKIPLOCALCHECK=$DEFAULT_SKIPLOCALCHECK
DD_BLOCKSIZE=$DEFAULT_DD_BLOCKSIZE
DD_PARMS=$DEFAULT_DD_PARMS
HARDLINKS=$DEFAULT_HARDLINKS
EXCLUDE_LIST=$DEFAULT_EXCLUDE_LIST
ZIP_BACKUP=$DEFAULT_ZIP_BACKUP
NOTIFY_UPDATE=$DEFAULT_NOTIFY_UPDATE
EXTENSIONS=$DEFAULT_EXTENSIONS
PARTITIONBASED_BACKUP=$DEFAULT_PARTITIONBASED_BACKUP
if [[ -z $DEFAULT_LANGUAGE ]]; then
	LANG_EXT=$(echo $LANG | tr '[:lower:]' '[:upper:]')
	DEFAULT_LANGUAGE=${LANG_EXT:0:2}
fi
LANGUAGE=$DEFAULT_LANGUAGE

# misc other vars

FAKE=0
HELP=0
BACKUPFILE=""
EXTENDED=0
DEPLOY=0
DIR_TO_BACKUP="/"
NOS=0
EXCLUDE_DD=0
UPDATE_MYSELF=0
FORCED_RC=0

while getopts ":a:Ab:B:cC:d:D:e:E:FG:hI:k:Kl:L:m:nN:o:p:Pr:R:s:t:u:UvVxXyz" opt; do
   case $opt in   
		5)	NOS=1
			;;
		A) 	APPENDLOG=1
			;;
		a) 	STARTSERVICES="$OPTARG"
			;;
		b)	DD_BLOCKSIZE="$OPTARG"
			;;
		B) 	DIR_TO_BACKUP="$OPTARG"
			;;
		c)  SKIPLOCALCHECK=1
			;;
		C)  FORCED_RC="$OPTARG"
			;;
		d) 	if (( $EXTENDED )); then
				RESTORE_DEVICE="$OPTARG"
			fi
			;;
		D)	DD_PARMS="$OPTARG"
			;;
		e)	EMAIL="$OPTARG"
			;;
		E)	EMAIL_PARMS="$OPTARG"
			;;
		F) 	FAKE=1
			;;
		G)	LANGUAGE="$OPTARG"
			LANGUAGE=$(echo $LANGUAGE | tr '[:lower:]' '[:upper:]')			
			;;
		k) 	KEEPBACKUPS="$OPTARG"
			;;
		K) 	HARDLINKS=$(( ! $HARDLINKS ))
			;;
		l) 	LOG_LEVEL="$OPTARG"
			;;
		L) 	LOG_OUTPUT="$OPTARG"
			;;
		m) 	MSG_LEVEL="$OPTARG"
			;;
		N)  EXTENSIONS="$OPTARG"
			;;
		n)  NOTIFY_UPDATE=$(( ! $NOTIFY_UPDATE ))
			;;
		o) 	STOPSERVICES="$OPTARG"
			;;
		p) 	BACKUPPATH="$OPTARG"
			;;
		P) 	PARTITIONBASED_BACKUP=1
			;;
		r) 	if (( $EXTENDED )); then
				RESTOREFILE="$OPTARG"
			fi
			;;
		R) 	if (( $EXTENDED )); then
				ROOT_PARTITION=$OPTARG
			fi
			;;
		s)	EMAIL_PROGRAM="$OPTARG"
			;;
		t) 	BACKUPTYPE="$OPTARG"
			;;
		u)	EXCLUDE_LIST="$OPTARG"
			;;
		U)	UPDATE_MYSELF=1
			;;
		v)	VERBOSE=1
			;;
		X)	EXTENDED=1
			;;
		x)	EXCLUDE_DD=1
			;;
		y)	DEPLOY=1
			;;
		z)	ZIP_BACKUP=1
			;;
		h)  HELP=1
			;;
		\?)	writeToConsole $MSG_LEVEL_MINIMAL $MSG_UNKNOWN_OPTION "-$OPTARG"
			mentionHelp
			exit 127
			;;
		:) 	writeToConsole $MSG_LEVEL_MINIMAL $MSG_OPTION_REQUIRES_PARAMETER "-$OPTARG"
			mentionHelp
			exit 127
			;;
    esac
done
shift $((OPTIND-1))

if (( $DEPLOY )); then
    deployMyself "$args"
else
	if (( $HELP )); then
		usage
		exit 0
	fi

	if (( $ETC_CONFIG_FILE_INCLUDED )); then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_INCLUDED_CONFIG "$ETC_CONFIG_FILE"		
	fi
	
	if (( $HOME_CONFIG_FILE_INCLUDED )); then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_INCLUDED_CONFIG "$HOME_CONFIG_FILE"
	fi

	checkAndCorrectImportantParameters	# no return if errors	
	
	if [[  -z "$DIR_TO_BACKUP" && -z "$RESTOREFILE" ]]; then
		restoreOpt=" -b"
		if (( $EXTENDED )); then
			restoreOpt="s -b or -r"
		fi
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_MISSING_OPTION "$restoreOpt"
		mentionHelp 
		exit 0			
	fi	

	if (( $UID != 0 )); then
		writeToConsole $MSG_LEVEL_MINIMAL $MSG_RUNASROOT "$0 $passedOpts"
		exit 127
	fi
	
	if (( $UPDATE_MYSELF )); then
		updateScript
		cleanupTempFiles
		exit 0
	fi

	setupEnvironment
	logOptions
	
	UPDATE_POSSIBLE=0
	if (( $NOTIFY_UPDATE )); then
		versions=( $(isNewVersionAvailable ) )
		rc=$?
		if [[ $rc == 0 ]]; then
			UPDATE_POSSIBLE=1
			latestVersion=${versions[0]}
			newVersion=${versions[1]}
			oldVersion=${versions[2]}

			writeToConsole $MSG_LEVEL_MINIMAL $MSG_NEW_VERSION_AVAILABLE "$newVersion" "$oldVersion"
			writeToConsole $MSG_LEVEL_MINIMAL $MSG_VISIT_VERSION_HISTORY_PAGE "$(getLocalizedMessage $MSG_VERSION_HISTORY_PAGE)"
		fi
	fi

	doit
fi	
