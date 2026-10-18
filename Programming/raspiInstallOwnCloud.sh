#!/bin/bash
#
# *** OwnCloud installer für Raspberry Wheezy ***
#
# Vorlage ist das Tutorial von www.forum-raspberypi.de zur Owncloudinstallation von ps915
#
# Steps die ausgeführt werden:
#
# 1) Bestimmung der aktuellen Owncloudversion von der Owncloud Webseite
# 2) Ausführung der Schritte aus dem Tutorial in zwei Durchgängen
#    a) Erster Durchgang berichtet was getan werden würde.
#    b) Danach wird gefragt ob installiert werden soll.
#    c) Bei ja werden im zweiten Durchgang die Änderungen vorgenommen.
#       Dabei wird falls eine Datei geändert wird immer die alte Datei 
#       vorher gesichert (Dateiname + .org)
# 3) Sämtliche Aktionen werden in einer LogDatei mitgeschrieben (Scriptname.log)
#
#####################################################################################################
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#####################################################################################################
#
# (c) 2013-2014 framp at linux-tips-and-tricks dot de
#

MYSELF="${0##*/}"
VERSION="0.1.1c"
URL="http://owncloud.org/install"
OWNCLOUD="owncloud"
LOG_FILE=${MYSELF/.sh/}.log
RUN_FILE=${MYSELF/.sh/}.done
rm -f $LOG_FILE 1>/dev/null 2>&1

exec 1> >(tee -a $LOG_FILE >&1)
exec 2> >(tee -a $LOG_FILE >&2)

echo "$MYSELF $VERSION"

if [[ ! "$(cat /etc/os-release)" =~ "ID=raspbian" ]]; then
	echo "??? Dieses Script funktioniert nur auf raspbian"
	exit 1
fi

if [ -f "/var/www/$RUN_FILE" ]; then 
	echo "@@@ Owncloud $(cat /var/www/$RUN_FILE) schon installiert"
	exit 1
fi

if (( $UID != 0 )); then
	echo "??? Skript muss mit sudo aufgerufen werden"
	exit 1
fi

actualDownload=$(curl $URL/#downloadModal 2>/dev/null| grep "Download.*href.*Unix" | sed "s/[^\"]*href=//" | sed "s/>.*//" | sed "s/\"//g")

OWNCLOUD_FILE=${actualDownload##*/}
OWNCLOUD_VERSION=$(echo $OWNCLOUD_FILE | sed -r 's/[a-z]+-//' | sed 's/tar.bz2//' | sed 's/\.$//')

echo "@@@ Aktuelle OwnCloud version: $OWNCLOUD_VERSION (Untersuchte url: $URL)"

pass=1

while (( $pass <= 2 )); do

	if [ ! -f "/home/pi/$OWNCLOUD_FILE" ]; then
		echo "+++ Lade $actualDownload runter..."
		if (( $pass == 2 )); then
:  		    pushd /home/pi
			if ! wget --no-check-certificate $actualDownload >/dev/null; then
				echo "??? Fehler beim Bestimmen der aktuellen Owncloudversion von $URL"
:			    popd
				exit 1
			fi
:           popd
		fi
	else
		echo "--- $OWNCLOUD_FILE schon runtergeladen"
	fi

	echo "+++ Führe aus: apt-get update" 
	(( $pass == 2)) && apt-get update 

	OUT="/etc/group"
	echo "@@@ Prüfe $OUT ..."
	if ! grep "www-data" $OUT 1>/dev/null; then
		echo "+++ Gruppe www-data wird erstellt ..."
		if (( $pass == 2 )); then
			groupadd www-data
			usermod -a -G www-data www-data
		fi
	else
		echo "--- Gruppe www-data existiert bereits"
	fi

	echo "+++ Führe aus: apt-get install -y apache2 php5 php5-gd php5-sqlite php5-curl php5-json php5-common php5-intl php-pear php-apc php-xml-parser libapache2-mod-php5 curl libcurl3 libcurl3-dev sqlite" 
	(( $pass == 2 )) && echo "Das wird jetzt etwas länger dauern... Bitte Geduld."  
	(( $pass == 2 )) && apt-get install -y apache2 php5 php5-gd php5-sqlite php5-curl php5-json php5-common php5-intl php-pear php-apc php-xml-parser libapache2-mod-php5 curl libcurl3 libcurl3-dev sqlite

	OUT="/etc/apache2/apache2.conf"
	echo "@@@ Prüfe $OUT ..."
	if ! grep "owncloud" $OUT 1>/dev/null; then
		echo "+++ Aenderung von $OUT..."
		if [ ! -f $OUT.org ]; then
			echo "+++ Sicherung von $OUT zu $OUT.org..."
			(( $pass == 2 )) && cp $OUT $OUT.org
		fi
		if (( $pass == 2 )); then
			echo "# added by $MYSELF"  >> $OUT
			echo "ServerName owncloud" >> $OUT
		fi
	else
		echo "--- $OUT ist bereits geaendert ..."
	fi

	OUT="/etc/hosts"
	echo "@@@ Prüfe $OUT ..."
	if ! grep "owncloud" $OUT 1>/dev/null; then
		echo "+++ Änderung von $OUT..."
		if [ ! -f $OUT.org ]; then
			echo "+++ Sicherung von $OUT zu $OUT.org..."
			(( $pass == 2 )) && cp $OUT $OUT.org
		fi
		if (( $pass == 2 )); then
			echo "# added by $MYSELF" >> $OUT 
			echo "127.0.0.1	owncloud" >> $OUT
		fi
	else
		echo "--- $OUT ist bereits geändert ..."
	fi

	OUT="/etc/apache2/sites-enabled/000-default"
	echo "@@@ Prüfe $OUT ..."
	match=0
	if [ -f $OUT ]; then
		while read line; do

			if [[ $line != "<Directory /var/www/>" ]]; then
				continue;
			else
				read line
				read line
				if [[ $line == "AllowOverride None" ]]; then
					match=1		
				fi
				break
			fi
		done <  $OUT
	else
		match=1
	fi

	if (( $match )); then
		echo "+++ Änderung von $OUT..."
		if [ ! -f $OUT.org ]; then
			echo "+++ Sicherung von $OUT zu $OUT.org..."
			(( $pass == 2 )) && cp $OUT $OUT.org
		fi
		if (( $pass == 2 )); then
			patch $OUT <<FiLeEnD
11c11
< 		AllowOverride None
---
> 		AllowOverride All
FiLeEnD
		fi
	else
		echo "$OUT ist bereits geändert ..."
	fi

	OUT="/etc/php5/apache2/php.ini"
	echo "@@@ Prüfe $OUT ..."
	if [[ ! -f "$OUT" || ! $(grep "upload_max_filesize = 2G" $OUT 1>/dev/null) ]]; then
		echo "+++ Aenderung von $OUT..."
		if [ ! -f $OUT.org ]; then
			echo "+++ Sicherung von $OUT zu $OUT.org..."
			(( $pass == 2 )) && cp $OUT $OUT.org
		fi
		if (( $pass == 2 )); then
			sed -i "s/upload_max_filesize = .*/# changed by $MYSELF\nupload_max_filesize = 2G/" $OUT
		else
			echo "--- $OUT ist bereits geaendert ..."

		fi
	fi

	if [[ ! -f "$OUT" || ! $(grep "post_max_size = 2G" $OUT 1>/dev/null) ]]; then
		echo "+++ Aenderung von $OUT..."
		if [ ! -f $OUT.org ]; then
			echo "+++ Sicherung von $OUT zu $OUT.org..."
			(( $pass == 2 )) && cp $OUT $OUT.org
		fi
		if (( $pass == 2 )); then
			sed -i "s/post_max_size = .*/# changed by $MYSELF\npost_max_size = 2G/" $OUT
		else
			echo "--- $OUT ist bereits geaendert ..."
		fi
	fi

	OUT="/var/www/index.html"
	echo "@@@ Prüfe $OUT ..."
	if [ ! -f $OUT.org ]; then
		echo "+++ Sicherung von $OUT zu $OUT.org..."
		(( $pass == 2 )) && mv $OUT $OUT.org
	fi
	if [ ! -f "/var/www/$RUN_FILE" ]; then 

		echo "+++ Installation von OwnCloud"
		if (( $pass == 2 )); then

			echo "Das wird jetzt etwas länger dauern... Bitte Geduld"
			a2enmod rewrite
			a2enmod headers

			/etc/init.d/apache2 restart

			echo "+++ Auspacken des tar files..."
:		    pushd /home/pi
			tar xvf $OWNCLOUD_FILE 
			echo "+++ Verschieben der Dateien ins Apache Verzeichnis..."
			mv owncloud/* /var/www
			mv owncloud/.htaccess /var/www
	
			echo "+++ Löschen des tar files..."
			rm -rf owncloud $OWNCLOUD_FILE
			chown -R www-data:www-data /var/www
			echo "@@@ Installation beendet"
			echo $OWNCLOUD_VERSION > /var/www/$RUN_FILE
:		    popd
		fi
	else
		echo "--- Owncloud $(cat /var/www/$RUN_FILE) schon installiert"
	fi

	if (( $pass <= 1 )); then
		echo -n "Installation beginnen? (j/n) "
		read a
		if [[ -z $a || ! "jJ" =~ $a ]]; then
                        echo "??? Installation abgebrochen"
                        exit 0
                fi
	fi

	((pass++))
done

# vim: tabstop=4:softtabstop=4:shiftwidth=4:noexpandtab:syntax=sh
