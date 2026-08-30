from datetime import datetime
from dateutil import tz

# Small proof of concept to get the geolocation of a given location on earth (Logitude and Latitude)
# and to get the actual sunrise and sunset time of the location by using network APIs available from
# google (geolocation) and sunrise-sunset.org (sunrise and sunset time) 
#
# (C) 2015 - framp at linux-tips-and-tricks dot de 

import requests

city="Berlin"
street="Bahnhofstrasse"
streetNumber="1"

query=True

if query:
	
	# get coordinates for location
	# https://developers.google.com/maps/documentation/geocoding/#GeocodingRequests
	
	request='http://maps.googleapis.com/maps/api/geocode/json?address=%s,%s,%s' % (city,street,streetNumber)
	r = requests.get(request)
	j=r.json()
	
	status=j['status']	
	if status != "OK":
		raise Exception("Request %s failed  with status code %s" % (request, status))
	
	if len(j['results']) < 1:
		raise Exception("Unable to find coordinates for %s - %s %s" % (city, street, streetNumber))
		
	lat=j['results'][0]['geometry']['location']['lat']
	lng=j['results'][0]['geometry']['location']['lng'] 
	
	# get sunset and sunrise time
	# http://sunrise-sunset.org/api
	
	request='http://api.sunrise-sunset.org/json?lat=%s&lng=%s&date=today' % (lat,lng)
	r=requests.get(request)
	j=r.json()
	
	status=j['status']	
	if status != "OK":
		raise Exception("Request %s failed  with status code %s" % (request, status))
	
	sunrise=j['results']['sunrise']	# UTC
	sunset=j['results']['sunset'] # UTC
	
else:	
	sunrise="3:49:11 AM"
	sunset="6:52:07 PM"

sunrise = datetime.strptime(sunrise, '%I:%M:%S %p').time()
sunset = datetime.strptime(sunset, '%I:%M:%S %p').time()

# add current date

now = datetime.now()
sunrise=datetime.strptime(now.strftime("%Y-%m-%d")+" "+sunrise.strftime("%H:%M:%S"),"%Y-%m-%d %H:%M:%S")
sunset=datetime.strptime(now.strftime("%Y-%m-%d")+" "+sunset.strftime("%H:%M:%S"),"%Y-%m-%d %H:%M:%S")

# convert to local time

fromZone = tz.tzutc()
toZone = tz.tzlocal()

sunrise = sunrise.replace(tzinfo=fromZone)
sunrise = sunrise.astimezone(toZone)

sunset = sunset.replace(tzinfo=fromZone)
sunset = sunset.astimezone(toZone)

print "Location: %s - %s %s" % (city, street, streetNumber)
print "Latitude: %s - Longitude: %s" % (lat, lng)
print "Sunrise: %s - Sunset: %s" % (sunrise, sunset)
