#!/usr/bin/env python 
#-*- coding: utf-8 -*-
#
# This script checks with ifconfig which WLAN channel is used by the current system and reports
# whether other SSIDs use the same channel or whether there are channel range overlaps 
# by other channels used by other SSIDs 
#
# You will get better scan results if you invoke the script as root. No change on the system will be done
# shell commands executed: 
# 1) iwlist scan
# 2) iwconfig
#
# Invoke script with any parameter to get the following sample result if there is a WLAN adapter available. 
# ---------------------------------------------------------------------------------------------------------
# WLAN channel analysis for SSID 'MyESSID' using channel 6 on wlan0
#
# Channels | 01 | 02 | 03 | 04 | 05 | 06 | 07 | 08 | 09 | 10 | 11 | 12 | 13 | SSIDs
#     1     *01**--------->                                                   Channel1
#     2     <----*01**--------->                                              OverlapChannel2
#     4          <---------*01**--------->                                    BorderChannel4
#     5               <---------*01**--------->                               InbetweenChannel5
#     6                    <---------*02**--------->                          * MyESSID, SameChannel6
#     9                                   <---------*01**--------->           OverlapChannel9
#    13                                                       <---------*01** Channel13
#
# SSIDs with identical channel    : 1 SameChannel6
# SSIDs with overlapping channels : 4 BorderChannel4, InbetweenChannel5, OverlapChannel2, OverlapChannel9
# Sum of detected SSIDs           : 8
# Minimal overlapped channels     : 11,12
#
# *** Switch your access point channel from 6 to an optimal channel 12 
# ----------------------------------------------------------------------------------------------------
#
# 05/03/12 framp at linux-tips-and-tricks dot de
# 03/30/15 Enhanced rating logic
#
# Credits: Thx for beta tests executed by members of minthouse.forumieren.com
#

import subprocess
import re
import sys
import os
from optparse import OptionParser

mySelf=os.path.basename(sys.argv[0])
version='0.4'
myVersion=mySelf+" V" + version
debug=False

class wlanScanner():

    def executeCommand(self,command):
        rc=None
        result=None
        try:
            proc = subprocess.Popen(command, stdout=subprocess.PIPE,shell=True)
            result = proc.communicate()[0]
            rc = proc.returncode
        except OSError, e:
            print "===> Error occured in command %s" % (command)
            raise e         
            
        return (rc,result)    
    
    def printOverlap(self,usageCount, scanChannel,suffix=""):
        
        print "   %2d     " % (scanChannel),
        for channel in range(1,14):
            if channel == scanChannel:
                sys.stdout.write ("*%.2d**" % (usageCount))
            elif channel == max(scanChannel-2,1):
                sys.stdout.write ("<----")
            elif channel == min(scanChannel+2,13):
                sys.stdout.write ("---->")
            elif channel >= max(scanChannel-2,1) and channel <= min(scanChannel+2,13):
                sys.stdout.write ("-----")
            else:
                sys.stdout.write ("     ")
        
        print " %s" % (suffix)
    
    def findCommand(self,command):
        pathes=['/sbin','/usr/bin','/usr/sbin','/bin']
        for path in pathes:
            (rc,result)=self.executeCommand('find  ' + path + ' -name ' + command + ' | head -n 1')
            if rc != 0:
                print "*** Error: Unable to execute " + command
                sys.exit(1)
            if result:
                return result.rstrip()
        return None

    def run(self,essid=None,testData=None):
    
        accessPoints=[]
        channelUsage=[0]*14
    
        if testData:
            scanEssid=testData['scanEssid']
            scanDevice=testData['scanDevice']
            scanChannel=testData['scanChannel']
    
            myDevs=[[scanDevice,scanEssid]]            
            accessPoints=testData['accessPoints']
            channelUsage=testData['channelUsage']
        
        else:
            myDevs=[]

            command=self.findCommand('iwconfig')
            (rc,result)=self.executeCommand(command + ' 2>/dev/null')
            if rc > 0:
                sys.exit(1)        
                
            result=result.split('\n')
    
            devFound=None
            for line in result:
                match=re.search('^(\S+).*IEEE',line,re.IGNORECASE)
                if match:
                    devFound=match.group(1)
                    if essid:
                        myDev=match.group(1)
                        myEssid=essid
                        myDevs.append((myDev,myEssid))
                        break    
                        
                match=re.search('^(\S+).*ESSID[^"]*"([^"]*)"',line,re.IGNORECASE)
                if match:
                    myDev=match.group(1)
                    myEssid=match.group(2)
                    myDevs.append((myDev,myEssid))
                    continue    
                    
            if not myDevs:
                if devFound:
                    print "*** Error: WLAN device %s not connected to an accesspoint. Use option -e" % (devFound)
                else:
                    print "*** Error: No WLAN device found"
                sys.exit(1)        
        
            (scanDevice,scanEssid)=myDevs[0]        
            
            if len(myDevs) > 1:
                print "*** Warning: More than one WLAN device found. Using %s for channel scans" % (scanDevice)        
        
            command=self.findCommand('iwlist')        
            (rc,result)=self.executeCommand(command + ' ' + scanDevice + ' scan')
            if rc > 0:
                sys.exit(1)        
        
            result=result.split('\n')
            essid=None
            channel=None
            scanChannel=None
            for line in result:
                match=re.search('ESSID[^"]*"([^"]*)"',line,re.IGNORECASE)
                if match:
                    essid=match.group(1)
                else: 
                    match=re.search('Channel[^\d]*(\d+)',line,re.IGNORECASE)
                    if match:
                        channel=int(match.group(1))
    
                if essid and channel:                    
                    accessPoints.append((essid,channel))
                    channelUsage[channel]+=1
                    if essid == scanEssid:
                        scanChannel=channel
                    (essid,channel)=(None,None)                
        
            if not scanChannel:
                print "*** Error: Unable to get channel used by %s" % (scanEssid)
                sys.exit(1)        
    
        print "\nWLAN channel analysis for SSID '%s' using channel %d on %s" % (scanEssid, scanChannel, scanDevice)
        print
        
        print "Channels | ",
        for channel in range(1,14):
            sys.stdout.write ("%.2d | " % (channel))
        print "SSIDs"
    
        overlappedChannelsSSID=[]
        identicalChannelsSSID=[]
        channelSSID=[ [] for i in xrange(0,14)]
        for (ssid,channel) in accessPoints:
            channelSSID[channel].append(ssid)
            if abs(channel - scanChannel) <= 4 and ssid != scanEssid:
                if channel != scanChannel:
                    overlappedChannelsSSID.append(ssid)
                else:
                    identicalChannelsSSID.append(ssid)
    
        identicalChannel=len(identicalChannelsSSID)
        identicalList = ', '.join(identicalChannelsSSID) if identicalChannel > 0 else ""         
    
        overlappedChannels=len(overlappedChannelsSSID) 
        overlappedList = ', '.join(overlappedChannelsSSID) if overlappedChannels > 0 else ""
        
        accessPoints=sorted(accessPoints, key=lambda ap: ap[1])
               
        processedChannels=[False]*14
        for (ssid,channel) in accessPoints: 
            if not processedChannels[channel]:
                suffix=""
                if channelSSID[channel]:
                    if ssid == scanEssid:
                        suffix="* "
                    suffix+=', '.join(channelSSID[channel]) 
                self.printOverlap(channelUsage[channel],channel,suffix)
                    
                processedChannels[channel] = True
        print
            
        print "SSIDs with identical channel    : %d %s" % (identicalChannel, identicalList)
        print "SSIDs with overlapping channels : %d %s" % (overlappedChannels, overlappedList)

        sumDetectedAPs=len(accessPoints)
        print "Sum of detected SSIDs           : %d" % (sumDetectedAPs)
    
        channelWeight=[0.55,0.72,1,0.72,0.55]
        
        channelUsage=[0]*14        
        for (ssid,channel) in accessPoints:
            if ssid != scanEssid: 
                actualWeight=0 if channel>=3 else 3-channel
                for c in xrange(max(1,channel-2),min(14,channel+3)):                        
                    channelUsage[c]+=channelWeight[actualWeight]
                    actualWeight+=1
        
        if debug:
                print "ChannelUsage: ", ["%.2f" % c for c in channelUsage[1:] ]
                
        minimum=min(channelUsage[1:])
        minimumChannels=[ c for c in xrange(1,14) if channelUsage[c] == minimum ]

        minimumChannelWeight=[0]*14
        for channel in minimumChannels:
            for c in xrange(max(1,channel-2),min(14,channel+3)):                        
                minimumChannelWeight[channel]+=channelUsage[c]
        
        if debug:
            print "MinimumWeight: ", ["%.2f" % w for w in minimumChannelWeight[1:]]        
        
        minimum = min([ minimumChannelWeight[c] for c in minimumChannels ])  
        minimumChannelWeights=[ [c,minimumChannelWeight[c]] for c in minimumChannels ]
                
        minimumChannels=[ str(e[0]) for e in minimumChannelWeights if e[1] == minimum]

        print                
        if len(minimumChannels) > 1:
            optimalChannels=','.join(minimumChannels[:-1])+' or ' + minimumChannels[-1]
        else:
            optimalChannels=minimumChannels[0:]
        
        if not str(scanChannel) in minimumChannels:                  
            print "*** Switch your access point channel from %s to optimal channel%s %s" % (scanChannel,['','s'] [len(optimalChannels)>1],''.join(optimalChannels))
        else:
            if len(optimalChannels) == 1:
                print "*** Your access point channel %s is optimal" % (scanChannel)
            else:
                print "*** Your access point channel %s is optimal but can also be changed to channel%s %s" % (scanChannel, ['','s'] [len(optimalChannels)>1], ''.join(optimalChannels))
            
        if testData:
            result={}
            result['identicalChannel']=identicalChannel
            result['identicalList']=identicalList
            result['overlappedChannels']=overlappedChannels
            result['overlappedList']=overlappedList
            result['sumDetectedAPs']=sumDetectedAPs
            result['channelUsage']=channelUsage
            result['minimumChannels']=minimumChannels
            return result

import unittest

class TestFunctions(unittest.TestCase):

    def setUp(self):
        self.scanner = wlanScanner
  
#    @unittest.skip("Works")
    def test_no1(self):
        testData={}
        scanChannel=6
        scanEssid='MyESSID1'
        testData['scanEssid']=scanEssid
        testData['scanDevice']='wlan0'
        testData['scanChannel']=scanChannel
        accessPoints=[]
        channelUsage=[0]*14
        accessPoints.append((scanEssid,scanChannel))
        testData['accessPoints']=accessPoints        
        testData['channelUsage']=channelUsage
        
        channelUsage[scanChannel]+=1
        accessPoints.append(("Channel1",1))
        channelUsage[1]+=1
        accessPoints.append(("Channel13",13))
        channelUsage[13]+=1
        accessPoints.append(("SameChannel6",scanChannel))
        channelUsage[scanChannel]+=1
        accessPoints.append(("BorderChannel4",4))
        channelUsage[4]+=1
        accessPoints.append(("InbetweenChannel5",5))
        channelUsage[5]+=1
        accessPoints.append(("OverlapChannel2",2))
        channelUsage[2]+=1
        accessPoints.append(("OverlapChannel9",9))
        channelUsage[9]+=1
        result=wlanScanner().run(testData=testData)        
        
        self.assertEqual(result['identicalChannel'],1,'Wrong number of equal channels')
        self.assertEqual(result['identicalList'],'SameChannel6','Wrong names of equal channels')
        self.assertEqual(result['overlappedChannels'],4,'Wrong number of overlapped channels')
        self.assertEqual(result['overlappedList'],'BorderChannel4, InbetweenChannel5, OverlapChannel2, OverlapChannel9','Wrong names of overlapped channels')
        self.assertEqual(result['sumDetectedAPs'],8,'Wrong number of APs')
        self.assertEqual(result['minimumChannels'],['12'],'Wrong minimum channels')

#    @unittest.skip("Works")        
    def test_no2(self):
        testData={}
        scanChannel=6
        scanEssid='MyESSID2'
        testData['scanEssid']=scanEssid
        testData['scanDevice']='wlan0'
        testData['scanChannel']=scanChannel
        accessPoints=[]
        channelUsage=[0]*14
        accessPoints.append((scanEssid,scanChannel))
        testData['accessPoints']=accessPoints        
        testData['channelUsage']=channelUsage
        
        channelUsage[scanChannel]+=1
        accessPoints.append(("Channel1",1))
        channelUsage[1]=1
        result=wlanScanner().run(testData=testData)        
        
        self.assertEqual(result['identicalChannel'],0,'Wrong number of equal channels')
        self.assertEqual(result['identicalList'],'','Wrong names of equal channels')
        self.assertEqual(result['overlappedChannels'],0,'Wrong number of overlapped channels')
        self.assertEqual(result['overlappedList'],'','Wrong names of overlapped channels')
        self.assertEqual(result['sumDetectedAPs'],2,'Wrong number of APs')
        self.assertEqual(result['minimumChannels'],['6','7','8','9','10','11','12','13'],'Wrong minimum channels')

#   @unittest.skip("Works")        
    def test_no3(self):
        testData={}
        scanChannel=9
        scanEssid='MyESSID3'
        testData['scanEssid']=scanEssid
        testData['scanDevice']='wlan0'
        testData['scanChannel']=scanChannel
        accessPoints=[]
        channelUsage=[0]*14
        accessPoints.append((scanEssid,scanChannel))
        testData['accessPoints']=accessPoints        
        testData['channelUsage']=channelUsage        
        channelUsage[scanChannel]+=1
        
        accessPoints.append(('C11',1))
        accessPoints.append(('C12',1))
        accessPoints.append(('C13',1))
        accessPoints.append(('C14',1))
        accessPoints.append(('C15',1))
        accessPoints.append(('C16',1))
        accessPoints.append(('C17',1))
        accessPoints.append(('C18',1))
        accessPoints.append(('C19',1))
        channelUsage[1]=9
        accessPoints.append(('C21',2))
        channelUsage[2]=1
        accessPoints.append(('C41',4))
        channelUsage[4]=1
        accessPoints.append(('C61',6))
        accessPoints.append(('C62',6))
        channelUsage[6]=2
        accessPoints.append(('C71',7))
        channelUsage[7]=1
        result=wlanScanner().run(testData=testData)        
        
        self.assertEqual(result['identicalChannel'],0,'Wrong number of equal channels')
        self.assertEqual(result['identicalList'],'','Wrong names of equal channels')
        self.assertEqual(result['overlappedChannels'],3,'Wrong number of overlapped channels')
        self.assertEqual(result['overlappedList'],'C61, C62, C71','Wrong names of overlapped channels')
        self.assertEqual(result['sumDetectedAPs'],15,'Wrong number of APs')
        self.assertEqual(result['minimumChannels'],['12','13'],'Wrong minimum channels')

#    @unittest.skip("Works")        
    def test_no4(self):
        testData={}
        scanChannel=6
        scanEssid='MyESSID4'
        testData['scanEssid']=scanEssid
        testData['scanDevice']='wlan0'
        testData['scanChannel']=scanChannel
        accessPoints=[]
        channelUsage=[0]*14
        accessPoints.append((scanEssid,scanChannel))
        testData['accessPoints']=accessPoints        
        testData['channelUsage']=channelUsage
        
        channelUsage[scanChannel]+=1
        accessPoints.append(("Channel2",1))
        channelUsage[2]=1
        accessPoints.append(("Channel9",9))
        channelUsage[10]=1
        result=wlanScanner().run(testData=testData)        
        
        self.assertEqual(result['identicalChannel'],0,'Wrong number of equal channels')
        self.assertEqual(result['identicalList'],'','Wrong names of equal channels')
        self.assertEqual(result['overlappedChannels'],1,'Wrong number of overlapped channels')
        self.assertEqual(result['overlappedList'],'Channel9','Wrong names of overlapped channels')
        self.assertEqual(result['sumDetectedAPs'],3,'Wrong number of APs')
        self.assertEqual(result['minimumChannels'],['13'],'Wrong minimum channels')
        
#    @unittest.skip("Works")        
    def test_no5(self):
        testData={}
        scanChannel=6
        scanEssid='MyESSID5'
        testData['scanEssid']=scanEssid
        testData['scanDevice']='wlan0'
        testData['scanChannel']=scanChannel
        accessPoints=[]
        channelUsage=[0]*14
        accessPoints.append((scanEssid,scanChannel))
        testData['accessPoints']=accessPoints        
        testData['channelUsage']=channelUsage
        
        channelUsage[scanChannel]+=1
        accessPoints.append(("Channel2",1))
        channelUsage[2]=1
        accessPoints.append(("Channel10",10))
        channelUsage[10]=1
        result=wlanScanner().run(testData=testData)        
        
        self.assertEqual(result['identicalChannel'],0,'Wrong number of equal channels')
        self.assertEqual(result['identicalList'],'','Wrong names of equal channels')
        self.assertEqual(result['overlappedChannels'],1,'Wrong number of overlapped channels')
        self.assertEqual(result['overlappedList'],'Channel10','Wrong names of overlapped channels')
        self.assertEqual(result['sumDetectedAPs'],3,'Wrong number of APs')
        self.assertEqual(result['minimumChannels'],['5','6'],'Wrong minimum channels')

#    @unittest.skip("Works")        
    def test_no6(self):
        testData={}
        scanChannel=6
        scanEssid='MyESSID6'
        testData['scanEssid']=scanEssid
        testData['scanDevice']='wlan0'
        testData['scanChannel']=scanChannel
        accessPoints=[]
        channelUsage=[0]*14
        accessPoints.append((scanEssid,scanChannel))
        testData['accessPoints']=accessPoints        
        testData['channelUsage']=channelUsage
        
        channelUsage[scanChannel]+=1
        accessPoints.append(("Channel2",1))
        channelUsage[2]=1
        accessPoints.append(("Channel2_1",2))
        channelUsage[2]=1
        accessPoints.append(("Channel2_2",2))
        channelUsage[2]+=1
        result=wlanScanner().run(testData=testData)        
        
        self.assertEqual(result['identicalChannel'],0,'Wrong number of equal channels')
        self.assertEqual(result['identicalList'],'','Wrong names of equal channels')
        self.assertEqual(result['overlappedChannels'],2,'Wrong number of overlapped channels')
        self.assertEqual(result['overlappedList'],'Channel2_1, Channel2_2','Wrong names of overlapped channels')
        self.assertEqual(result['sumDetectedAPs'],4,'Wrong number of APs')
        self.assertEqual(result['minimumChannels'],['7','8','9','10','11','12','13'],'Wrong minimum channels')

#    @unittest.skip("Works")        
    def test_no7(self):
        testData={}
        scanChannel=6
        scanEssid='MyESSID7'
        testData['scanEssid']=scanEssid
        testData['scanDevice']='wlan0'
        testData['scanChannel']=scanChannel
        accessPoints=[]
        channelUsage=[0]*14
        accessPoints.append((scanEssid,scanChannel))
        testData['accessPoints']=accessPoints        
        testData['channelUsage']=channelUsage
        
        channelUsage[scanChannel]+=1
        accessPoints.append(("Channel2",1))
        channelUsage[2]=1
        accessPoints.append(("Channel10_1",10))
        channelUsage[10]=1
        accessPoints.append(("Channel10_2",10))
        channelUsage[10]+=1
        result=wlanScanner().run(testData=testData)        
        
        self.assertEqual(result['identicalChannel'],0,'Wrong number of equal channels')
        self.assertEqual(result['identicalList'],'','Wrong names of equal channels')
        self.assertEqual(result['overlappedChannels'],2,'Wrong number of overlapped channels')
        self.assertEqual(result['overlappedList'],'Channel10_1, Channel10_2','Wrong names of overlapped channels')
        self.assertEqual(result['sumDetectedAPs'],4,'Wrong number of APs')
        self.assertEqual(result['minimumChannels'],['5'],'Wrong minimum channels')

#
# *** MAIN ***
#

parser = OptionParser(usage="%prog [-h] [-e ESSID] [-t] [-d]", version=myVersion)
parser.add_option("-e", "--essid", dest="essid",
              help="Don't discover ESSID form existing WLAN connection and use essid passed")
parser.add_option("-t", "--test", dest="test", action="store_true",
              help="Execute self test")
parser.add_option("-r", "--rating", dest="debug", action="store_true",
              help="Write details about the channel rating")

(options, args) = parser.parse_args()

debug=options.debug

print myVersion
           
if options.test:
    suite = unittest.TestLoader().loadTestsFromTestCase(TestFunctions)
    unittest.TextTestRunner(verbosity=5).run(suite)
else:
    wlanScanner().run(essid=options.essid)
