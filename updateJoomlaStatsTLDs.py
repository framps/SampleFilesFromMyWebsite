# -*- coding: utf-8 -*-
import MySQLdb
import sys
import commands
import re
import string
import subprocess
from optparse import OptionParser

"""
    Check all jommlastats entries for correct top level domain entries for IPs marked as US IPs
    and update the entries accordingly with help from ripe if they are not from US

    These updates will take time ... be patient

    1/8/2011 framp at linux-tips-and-tricks dot de
"""

parser = OptionParser()
parser.add_option("-s", "--host", action="store", dest="host", help="hostname")
parser.add_option("-u", "--user", action="store", dest="user", help="username")
parser.add_option("-p", "--password", action="store", dest="pwd", help="password")
parser.add_option("-d", "--database", action="store", dest="db", help="database")

(options, args) = parser.parse_args()

try:
    conn = MySQLdb.connect (host = options.host,user = options.user,passwd = options.pwd,db = options.db)

    cursor = conn.cursor()
    cursor2 = conn.cursor()

    cursor.execute("""select ip,tld from jos_jstats_ipaddresses
                            WHERE tld='us' order by ip desc
                    """);

    rowCount=cursor.rowcount
    leftRowCount=rowCount
    changedCount=0
    while True:
        print "Rows detected: %d" % leftRowCount
        print "Are you shure to process all these items (will take some time ...) ? (y/n)",
        s = sys.stdin.readline()
        if s.lower()[0] == 'y':
            break

    while True :
        row=cursor.fetchone()
        if not row:
            break
        ip = row[0]
        tld = string.upper(row[1])
        proc = subprocess.Popen("whois %s | grep -i country" % row[0], shell=True, stdout=subprocess.PIPE)
        result  = proc.stdout.read().strip()
        print "Items left: %d/%d - Changed: %d - Processing IP: %s (%s)" % (leftRowCount,rowCount,changedCount,ip,tld)
        leftRowCount=leftRowCount-1
        result=string.upper(result)
        tldOK=string.find(result,tld)
        if tldOK==-1:
            foundTLD=None
            for line in result.split('\n'):
                r=re.search('.*COUNTRY:\s+(\S+)',line)
                if r:
                    foundTLD=r.group(1).lower()
                    if foundTLD != "au":
                        break
            if foundTLD:
                print "Updating tld of %s from %s to %s" % (ip,tld,foundTLD)
                changedCount=changedCount+1
                cursor2.execute("""update jos_jstats_ipaddresses set tld=%s
                                    WHERE ip=%s
                                """,[foundTLD,ip]);

    conn.close ()

except MySQLdb.Error, e:
    print "Error %d: %s" % (e.args[0], e.args[1])
    sys.exit (1)

