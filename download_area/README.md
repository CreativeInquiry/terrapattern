Download Area
======

This script helps you download map tiles at a certain level for a particular area as specified by a bounding box of points. It will first calculate how many map tiles to download for a particular zoom level and save those to a csv file called "points.csv". Then it will download a map tile for each point in the csv file. 

You need to adjust two things to run the script: the bouding box for the points to download (starting on line 44) and zoom level / offset numbers (lines 14-19).

Specifically, you need to specify and latitude and longitude offset corresponding to the angular distance that each tile covers for any given zoom level you wish to download tiles for. We provide the latitude and longitude offsets for zoom levels 18 and 19. You simply have to comment out or edit the relevant lines of code. 

	# Adjust for different zoom levels
	#DEFAULT_ZOOM = 18 
	#lngOffset = 0.001386
	#latOffset = 0.001373
	
	DEFAULT_ZOOM = 19
	lngOffset = 0.000694
	latOffset = 0.000686
	
The offsets are calculated as follows. You can use a quick trick assuming that:

* 111,111 meters in the y direction is 1 degree of latitude. 
* 111,111 * cos(latitude) meters in the x direction is 1 degree of longitude

You also need to know that:

* Each map tile is 256x256 pixels
* Each zoom level features a resolution defined in meteres per pixel. You can find a list of resolutions [here](http://wiki.openstreetmap.org/wiki/Zoom_levels). For level 19, the resolution is 0.298 meters / pixel. 

To calculate the latitude offset use the formula:

	((resolution * length of tile) * 1) / 111111 
		
at zoom level 19 that would be:

	(0.298 * 256) * 1 / 111111 = 0.00068659268
	
To calculate the longitude offset use the formula:

	((resolution * height of tile) * 1) / (111111 * cos(latitude))
	
at zoom level 19, for an example latitude of 26.624824 that would be

	((0.298 * 256) * 1) / (111111 * cos(26.624824)) = 0.0087316879

## Where do these numbers come from?

Well, let's go back to history. The origins of the meter date back to the 18th century, to a time when there were two competing standards for a unit of length. One approach suggested defining a meter as the length of a pendulum having a half-period of one second. Another approach suggested using the circumference of the earth: a meter would equal one ten-millionth of the length of the earth's meridian along a quadrant. 

The latter approach won and the meter was defined soon after the French Revolution as equal to 10^-7 or one ten-millionth of the length of the meridian through Paris from pole to the equator. In other words, 10^7 meters would be the distance along the Paris meridian from the equator to the north pole. 

What follows is that 10^7 meters / 90 degrees = 111,111.111111 meters / degree.

Source: [http://physics.nist.gov/cuu/Units/meter.html](http://physics.nist.gov/cuu/Units/meter.html)


## How to run

Make sure you have these libraries
	
	brew install geos
	
and
	
	gem install rgeo

Assuming you have set your environment variables in a .env file in the parent directory, simply run

	ruby download_area/download_area.rb

## Resources

[geojson.io](http://geojson.io/) is a useful app for visualizing and editing geojson files.
