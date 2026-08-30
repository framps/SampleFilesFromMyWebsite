#!/usr/bin/groovy

/*
 Dieses Script entstand anlaesslich des kalten Wetters anno 2012
 und der Diskussion im Minthouse bzgl Temperaturumrechungen
 und ist dem Minthouse fuer den naechsten BibberWinter gewidmet

 Aufruf: Bibber -48 20 55
 Ergebnis: Liste aller umgerechneten Temperaturen fuer die Aufrufargumente

 04/26/12 framp at linux-tips-and-tricks dot de
 03/30/15 - fixed typo in error message
*/

import java.text.DecimalFormat

def C2F = { c -> [c * 1.8 + 32, "CF"] }
def F2C = { f -> [(f-32) * 5/9,"FC"] }
def C2R = { c -> [c * 0.8, "CR"] }
def R2C = { r -> [r * 1.25, "RC"] }
def F2R = { f -> [(f-32) * 4/9, "FR"] }
def R2F = { r -> [r * 2.25 + 32, "RF"] }

def conversions = [ C2F, C2R, F2C, F2R, R2C, R2F ]

def oneArgProcessed = false

args.each { arg ->		
       
    if (arg.isInteger()) {
      arg=arg.toInteger()

      if (oneArgProcessed)
          println "-"           
      else
          oneArgProcessed = true
        
      conversions.each {	
          (v,c) = it(arg)
          def value=new DecimalFormat("0.00").format(v)
          (f,t)=c as List
          println "$arg($f) = $value($t)"
      } 
    }
       
    else {
      println "Invalid number $arg skipped"
    }
} 
