#!/usr/bin/env python
# -*- coding: utf-8 -*-

from urllib2 import urlopen, HTTPError
from contextlib import closing
import json

# Retrieve location information of IP used by caller

url = 'http://ip-api.com/json/'
try:
	with closing(urlopen(url)) as response:
		location = json.loads(response.read())
		
		print " --- ip-api --- "
		print "  Location:	 %s" % (location['city'])
		print "  Longitude:	%s" % (location['lon'])
		print "  Latitude:	 %s" % (location['lat'])
		print "  regionName:  %s" % (location['regionName'])
		print "  CountryCode:  %s" % (location['countryCode'])

		print "\nJSON response: \n%s" % (json.dumps(location, sort_keys=True, indent=3).decode('unicode_escape'))
		
except HTTPError, e:
	print " --- ip-api failed to deliver location of IP used with HTTP RC %s" % (response.getcode())
	print "Caught exception %s" % (e)
