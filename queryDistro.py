#!/usr/bin/env python

import commands
import re

def queryDistro ():

#################################################################################
# Query distro the script runs on
#################################################################################
#
# Returned distro       Distribution the script was tested on
# ---------------------------------------------------------
# opensuse              openSuSE 11.0 (no lsb_release) and 11.2 (lsb_release)
# fedora                Fedora 12
# centos                CentOS 5.4
# kubuntu               Kubuntu 9.10
# debian                Debian 5.0.3
# arch                  Arch
# slackware             Slackware 13.0.0.0.0
# mandriva              Mandriva 2009.1
# debian                Knoppix 6.2
# linuxmint             Mint 8
#
# 10/08/29:: framp at linux-tips-and-tricks dot de
# 
#################################################################################
    
    detectedDistro = "Unknown"

    command = r"lsb_release -d 2>/dev/null"
    (rc, result) = commands.getstatusoutput(command)
    
    if rc == 0:
        nameGroup = re.search('Description:\s*([^ ]*)', result)

        if nameGroup:
            detectedDistro = nameGroup.groups()[0]
        else:
            assert False, "??? Should not occur: Don't find distro name in lsb_release output ???"
   
    else:
        command = r"ls /etc/*[-_]{release,version} 2>/dev/null"
        (rc, etcFiles) = commands.getstatusoutput(command)
        etcFiles=etcFiles.split('\n')
     
        for file in etcFiles:
            nameGroup = re.search('/etc/(.*)[-_]', file)
            if nameGroup:
                detectedDistro = nameGroup.groups()[0]
            else:
                assert False, "??? Should not occur: Don't find any etcFiles ???"

    detectedDistro = detectedDistro.lower()
        
    otherDistros = { 'suse': 'opensuse', 
                    'linux': 'linuxmint'}
    
    if detectedDistro in otherDistros:
        detectedDistro = otherDistros[detectedDistro]
    
    return detectedDistro

if __name__ == "__main__":
    print "Detected distro: " + queryDistro()
