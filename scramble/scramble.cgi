#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Small sample cgi program in Python and corresponding html page
#
# Accepts any text and returns the scrambled text
# Scramble rule:
# 1) Don't scramble a word with less than 4 characters
# 2) Keep the first and last character of the word and scramble the rest   
# 
# 04/14/12 framp at linux-tips-and-tricks dot de

import cgitb; cgitb.enable()

debugme  = False                                 # True=test from cmd line
inputkey = 'textToScramble' 
scramblekey  = 'Scramble'       

class dummy:                                     # mocked-up input obj
    def __init__(self, str): self.value = str

import cgi, sys, re, random, os, array
import xml.sax.saxutils
from datetime import datetime

if debugme:
    form = {inputkey: dummy(sys.argv[1])}       # name on cmd line
else:
    form = cgi.FieldStorage()                    # parse real inputs

print 'Content-type: text/html; charset=utf-8'
print

import os
language=os.environ['HTTP_ACCEPT_LANGUAGE']
german=language.lower().startswith('de')

print '<H1>Buchstaben aller Worte im Text durchmischen/Scramble text</H1><HR>'

def scramble(text): 

    result=''

    lines=text.split('\n')
    for line in lines:
   
        words = line.split()                    # Worte splitten und Spaces removen

        for word in words:
            if len(word) > 3:
                l=list(word)     
                first=l.pop(0)   
                last=l.pop()     
                random.shuffle(l)
                result+=''.join([first]+l+[last])+ ' ' # alles wieder zusammenbauen
            else:
                if len(word) > 0:				# skip empty words 
                    result+=word+' '

        result+='<br/>'

    return result
    
if not form.has_key(inputkey):

    if german:
        text=u"""Aufgrund einer Studie an einer Englischen Universität ist es egal, in welcher Reihenfolge die Buchstaben in
einem Wort stehen, das einzig wichtige dabei ist, dass der erste und letzte Buchstabe am richtigen Platz sind.
Der Rest kann totaler Blödsinn sein, und du kannst es trotzdem ohne Probleme lesen. Das geht deshalb, weil
wir nicht Buchstabe für Buchstabe einzeln lesen, sondern Wörter als Ganzes. Stimmt's?"""
    else: 
        text=u"""According to a researcher at Cambridge University, it doesn't matter in what order the letters in a word are,
the only important thing is that the first and last letter be at the right place. The rest can be a total mess and you can 
still read it without problem. This is because the human mind does not read every letter by itself but the word as a whole."""

else:
     text = form[inputkey].value		
     text = re.sub(u"[^a-zA-Z0-9ÄäÖöÜüß \n]", "", unicode(text,'utf-8'))	# nur Buchstaben und Zahlen erlauben

result=scramble(text)

print '<H3>Original Text</H3><P><PRE>'
print text.encode('utf-8')
print '</PRE></P><HR/>'
print '<H3>Text mit durchwürfelten Worten/Scrambled text</H3><P><PRE>'
print result.encode('utf-8')
print '</PRE></P><HR/>'

print """<form method=GET action="../scramble.html"> <input type=Submit value="Neuen Text eingeben/Enter nexw text" name="Return"> </form>"""
print """<form method=PUT action="scramble.cgi"> <input type=Submit value="Text neu mischen/Scramble new text" name="Scramble">""" + '<input type=hidden value="' + text.encode('utf-8') + '" name="textToScramble"> </form>'
