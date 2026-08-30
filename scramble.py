#!/usr/bin/python
# -*- coding: utf-8 -*-

# Small sample program in Python 
#
# Accepts any text and returns the scrambled text
# Scramble rule:
# 1) Don't scramble a word with less than 4 characters
# 2) Keep the first and last character of the word and scramble the rest   
# 
# 04/14/12 framp at linux-tips-and-tricks dot de

import fileinput
import random
import re
import urllib
import getopt
import sys
import os

def scramble(line):
    
    words = line.split()                    # Worte splitten und Spaces removen

    for word in words:
        word =re.sub(u"[^a-zA-Z0-9ÄäÖöÜüß]", "", unicode(word,'utf-8'))    # nur Buchstaben und Zahlen erlaubt
        if len(word) > 3:
            l=list(word)                    # String in Liste umwandeln
            first=l.pop(0)                  # erstes Zeichen retten
            last=l.pop()                    # letztes Zeichen retten
            random.shuffle(l)               # mischen
            print ''.join([first]+l+[last]),# alles wieder zusammenbauen
        else:
            print word,
    print


def scrambleWebsite(url):                   # Prozessiere eine webseite (muss plain Text sein)
    filehandle = urllib.urlopen(url)

    for line in filehandle.readlines():
        scramble(line)        
    filehandle.close()

def main(url=None):
    random.seed()

    if url:
        scrambleWebsite(url)
    
    else:
        for line in fileinput.input():              # von stdin lesen    
        
            if line.startswith('http://'):
                scrambleWebsite(line)
            else:
                scramble(line)
            
if len(sys.argv) == 1:
    print "Usage:"
    print "No parameter"
    print "   Use some default text"
    print "One parameter"
    print "   fileName: Filename with text to read. If a line starts with http:// the text is read from the urls" 
    print "   -: Read text from console"
    print 
     
    main('http://www.linux-tips-and-tricks.de/scramble.txt')
else:
    main()

