#!/usr/bin/python
#-*- coding: utf-8 -*-

import sys
import re
import os

"""
    Funktion: Vergleicht zwei Dateien die mit 'rpm -qa | sort > rpm_xx.yy' erzeugt wurden um herauszufinden welche Pakete sich
             in der alten Installation (erste Datei file) befinden und in der neuen Installation (zweite Datei)
             Der letzte Parameter kann ein regulärer Ausdruck sein um bestimmte Pakete von der Liste auszuschliesen, z.B. "(lib|yast2|sax2|bundle)"
             schliesst alle Pakete die mit lib oder yast2 oder sax2 oder bundle beginnen aus.

             Beispiel: Erstelle eine Datei auf der alten Installation als root mit 'rpm -qa | sort > rpm_11.2.lst'
                 und erstelle eine Datei auf der neuen Installation als root mit 'rpm -qa | sort > rpm_11.4.lst'
                 Danach dieses Script aufrufen mit
                     ./compareDistroRPMs.py rpm_11.2.lst rpm_11.4.lst "(lib|yast2|sax2|bundle)

    Purpose: Compare two files created with 'rpm -qa | sort > rpm_xx.yy' listings to find out which packages were installed
             in the old installation (first file) and are not installed in the new installation (second file)
             Last parameter can be a regular expression of to exclude some packages from the list, e.g. "(lib|yast2|sax2|bundle)"
             excludes all packages starting with lib or yast2 or sax2 or bundle

             Example: Create listing on old installation as root with 'rpm -qa | sort > rpm_11.2.lst'
                 and create listing on new installation as root with 'rpm -qa | sort > rpm_11.4.lst'
                 Then call this script with
                     ./compareDistroRPMs.py rpm_11.2.lst rpm_11.4.lst "(lib|yast2|sax2|bundle)"

    6/19/11 framp at linux-tips-and-tricks dot de
"""


def extract(fileName):
    result=[]
    rpmFrom=open(fileName,'r')
    for fromLine in rpmFrom:
        finish=False
        while not finish:
            m=re.match("^(.*)-([0-9\.\-]+)+",fromLine)
            if m:
                fromLine=m.group(1)
            else:
                finish=True
        result += [ fromLine ]

    rpmFrom.close()
    return result

def main(argv):

    excludeList = False
    if len(sys.argv) < 3:
        print "Usage: " + os.path.basename(sys.argv[0]) + " oldRPMFile newRPMFile [excludeRegex]"
        sys.exit(-1)

    if not os.path.exists(sys.argv[1]):
        print "??? %s not found" % (sys.argv[1])
        sys.exit(-1)

    if not os.path.exists(sys.argv[2]):
        print "??? %s not found" % (sys.argv[2])
        sys.exit(-1)

    if len(sys.argv) == 4:
        excludeList=sys.argv[3]

    rpmFrom=extract(sys.argv[1])
    rpmTo=extract(sys.argv[2])

    intersection = [val for val in rpmFrom if val in rpmTo]
    noFrom = [val for val in rpmFrom if not val in intersection]

    print "*** Following files were installed in %s but not in %s ***\n" % (sys.argv[1],sys.argv[2])
    for e in noFrom:
        if excludeList:
            if not re.match(excludeList,e):
                print e
        else:
            print e

if __name__ == '__main__':
    main(sys.argv)
