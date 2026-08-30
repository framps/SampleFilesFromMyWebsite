#!/usr/bin/python
# -*- coding: utf-8 -*-
import os
import re
import sys
import getopt

"""
    Ersetzt alle deutschen Umlaute ä,ö und ü sowie ß in Dateinamen und Verzeichnissen durch ae, oe und ue sowie ss
    Optional können alle Zeichen, die nicht Buchstaben oder Zahlen sind durch ein anderes Zeichen ersetzt werden.
    
    Optionen:
    -h: Anzeige des Hilfetextes
    -a: Anderungsmodus: Ohne diesen Parameter werden keine Verzeichnisse und Dateien umbenannt sondern nur Meldungen rausgeschrieben was getan würde wenn das Flag angegeben wird
    -v: AusführlicherModus: Es werden Meldungen geschrieben, die es erlauben zu verfolgen welche Verzeichnisse gerade bearbeitet werden
    -f: ÜberschreibModus: Falls die umbenannten Verzeichnisse oder Dateien existieren werden sie überschrieben. Ohne dieses Flag wird eine Fehlermeldung geschrieben und nicht überschrieben.
    -d: Angabe des StartVerzeichnisses welches rekursive bearbeitet werden soll. Falls es nicht angegeben wird ist es das aktuelle Verzeichnis
    -z: Alle Zeichen im Namen die nicht Buchstaben oder Zahlen sind werden durch diesen Buchstaben ersetzt 

    v0.1 -  4.6.2011 - Initiale Version
    v0.2 - 30.4.2013 - Aufnahme des Parameters -z und Ändern des Parameters -t in -a

    framp at linux-tips-and-tricks dot de

"""
VERSION="0.2"

reps = {'ä':'ae', 'ö':'oe', 'ü':'ue', 'Ä':'AE', 'Ö':'OE', 'Ü':'UE', 'ß':'ss'}

umlauts=""
for c in reps.keys():
    umlauts+=c

umlauts = "["+umlauts+"]"
umlautsRe = re.compile(umlauts)

renamedFiles=0
skippedFiles=0
overwrittenFiles=0
defaultReplace=None
defaultReplaceRegex=ur"^a-zA-Z0-9"

testMode=True
testModeMessage="TESTMODE: "
startDirectory="."
verbose=False
forceMode=False

def usage():
    print "%s %s" % (os.path.basename(sys.argv[0]),VERSION)
    print
    print "    Ersetzt recursiv alle deutschen Umlaute und ß in Dateinamen und Verzeichnissen durch ae,oe,ue und ss"
    print "    Optional können alle Zeichen, die nicht Buchstaben oder Zahlen sind durch ein anderes Zeichen ersetzt werden."
    print '''Aufruf: %s [OPTIONEN]... [STARTVERZEICHNIS]
               
               Optionen: 
    
                       -h --hilfe
                       -a --aktion - ausführen der Änderungen
                       -d Startverzeichnis --directory Startverzeichnis
                       -v --verbose
                       -z Standardzeichen --zeichen Standardzeichen 
                          Standardzeichen welches eingesetzt wird für Zeichen die nicht Buchstaben oder Zahlen sind 
                       -f --force''' % (os.path.basename(sys.argv[0]))
    print
    print "Standard Startverzeichnis ist das aktuelle Verzeichnis"

def pluralize(number):
    if number > 1 or number == 0:
        return "e"
    else:
        return ""    

def replaceAll(text, dic):
    for i, j in dic.iteritems():
        text = text.replace(i, j)
    if defaultReplace:
        text=re.sub(defaultReplaceRegex,defaultReplace,text)
    return text

def renameUmlauts(root, oldName):
    global renamedFiles, skippedFiles, overwrittenFiles

    newName = replaceAll(oldName, reps)
    if not os.path.exists(root+"/"+newName):
        print "%s--- '%s' wird zu '%s' umbenannt" % (testModeMessage,root+"/"+oldName,root+"/"+newName)
        renamedFiles+=1
        if not testMode:
            os.rename(root+"/"+oldName,root+"/"+newName)
    elif forceMode:
        print "%s!!! '%s' wird zu '%s' umbenannt und löscht existierende Datei/Verzeichnis" % (testModeMessage,root+"/"+oldName,root+"/"+newName)
        overwrittenFiles=+1
        if not testMode:
            os.rename(root+"/"+oldName,root+"/"+newName)        
    else:
        skippedFiles=+1
        print "%s??? '%s' kann nicht zu '%s' umbenannt werden da neue Datei/Verzeichnis schon existiert" % (testModeMessage,root+"/"+oldName,root+"/"+newName)

try:
    opts, args = getopt.getopt(sys.argv[1:], "avfhd:z:", 
                                  ["aktion",
                                "verbose",
                                "force",
                                "help",
                                "directory",
                                "zeichen"]); 

except getopt.GetoptError, err:
    print str(err) # will print something like "option -a not recognized"
    usage()
    sys.exit(0)
        
for o, a in opts:
    if o in ("-a", "--aktion"):
        testMode = False
        testModeMessage=""
    elif o in ("-d", "--directory"):
        startDirectory=a                                    
    elif o in ("-z", "--zeichen"):
        defaultReplace=a
        if len(defaultReplace) > 1:
            print "??? Ersetzungszeichen %s zu lang" % (defaultReplace)
        defaultReplaceRegex+=defaultReplace;                                                    
    elif o in ("-f", "--force"):
        forceMode=True                                
    elif o in ("-v", "--verbose"):
        verbose=True                                
    elif o in ("-h", "--help"):
        usage()
        sys.exit(0)                                
    else:
        assert False, "Unhandled option " + o    
    
if not os.path.exists(startDirectory):
    print "??? Startverzeichnis %s existiert nicht" % (startDirectory)    
    sys.exit(2)

defaultReplaceRegex="["+defaultReplaceRegex+"]"

for root, dirs, files in os.walk(startDirectory,topdown=False):
    if verbose:
        print "%s--- Bearbeite Verzeichnis '%s'" % (testModeMessage,root)
    for f in files:
        if verbose:
            print "%s--- Bearbeite Datei '%s'" % (testModeMessage,f)
        if re.search(umlautsRe,f) or (defaultReplace and re.findall(defaultReplaceRegex,f)):
            renameUmlauts(root,f)
    for d in dirs:
        if verbose:
            print "%s--- Bearbeite Verzeichnis '%s'" % (testModeMessage,d)
        if re.search(umlautsRe,d) or (defaultReplace and re.findall(defaultReplaceRegex,d)):
            renameUmlauts(root,d)

print "%s*** %d Element%s umbenannt" % (testModeMessage,renamedFiles-skippedFiles, pluralize(renamedFiles-skippedFiles))
if not forceMode:
    print "%s*** %d Element%s übersprungen" % (testModeMessage,skippedFiles, pluralize(skippedFiles))
else:
    print "%s*** %d Element%s überschrieben" % (testModeMessage,overwrittenFiles, pluralize(overwrittenFiles))
