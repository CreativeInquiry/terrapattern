# Example code for about 650 square miles around Port au Prince, Haiti

require 'rgeo'
require 'rgeo/geo_json'
require 'json'
require 'typhoeus'
require 'dotenv'
require 'uri'
require 'fileutils'

Dotenv.load

#$$c(W 74°13'51"--W 73°40'16"/N 40°58'38"--N 40°33'25")

DEFAULT_ZOOM = 19 # Adjust for different zoom levels
BOTTOM_CROP = 23
IMAGE_SIZE = 256
CONCURRENT_DOWNLOADS = 100
SLEEP_BETWEEN_DOWNLOADS = 0
dir = "#{File.dirname(__FILE__)}/results"
FileUtils.mkdir_p(dir)


## This is a rough estimate of the number of pixels at zoom level 18.
# Adjust this section for different zoom levels
# Use the quick and dirty estimate that 111,111 meters (111.111 km) in the y direction is 1 degree (of latitude) and 111,111 * cos(latitude) meters in the x direction is 1 degree (of longitude).
# Level 18 resolution: 0.596 m / pixel
# Level 19 resolution: 0.298 m / pixel
# 256 x 256 tiles

#Level 18
#lngOffset = 0.001386
#latOffset = 0.001373

#Level 19
lngOffset = 0.000694
latOffset = 0.000686


$hydra = Typhoeus::Hydra.new


# Adjust this geojson section to represent the bounding box for area to download
str = <<GEOJSON
{
  "type": "Feature",
  "properties": {
    "GEO_ID": "0500000US42003",
    "STATE": "42",
    "COUNTY": "003",
    "NAME": "Port_au_Prince",
    "LSAD": "County",
    "CENSUSAREA": 617.612
  },
  "geometry": {
    "type": "Polygon",
    "coordinates": [
      [
        [-72.35101321712136,18.695163512807298],
        [-72.39907840266824,18.62750672364368],
        [-72.41830447688699,18.596271421969803],
        [-72.46224978938699,18.5520116038241],
        [-72.47254947200418,18.502531167269215],
        [-72.44714358821511,18.455641769258598],
        [-72.35101321712136,18.385935258227804],
        [-72.24526980891824,18.374857793577064],
        [-72.13128665462136,18.398966658229426],
        [-72.05987552180886,18.454339102993643],
        [-72.03240970149636,18.524017852621213],
        [-72.02691653743386,18.578048182449344],
        [-72.03721622005105,18.649628257384915],
        [-72.06674197688699,18.727681201327876],
        [-72.13952640071511,18.78359698764211],
        [-72.25213626399636,18.793997879064417],
        [-72.32766726985574,18.75369084866755]
        
      ]
    ]
  }
}
GEOJSON


## This finds the bounding box of the geojson.  
p0 = JSON.parse(str)["geometry"]["coordinates"].first.first
maxLat, maxLng = p0
minLat, minLng = p0
JSON.parse(str)["geometry"]["coordinates"].first.each do |lat,lng|
  maxLat = lat if lat > maxLat
  print "maxLat ", maxLat, "  "
  minLat = lat if lat < minLat
  print "minLat ", minLat, "  "
  maxLng = lng if lng > maxLng
  print "maxLng ", maxLng, "  "
  minLng = lng if lng < minLng
  print "minLng ", minLng, "  "
  print "\n\n"
end




# This is the silly Java-ish initialization for the geography engine
factory = ::RGeo::Geos.factory

# This parses the geoJSON and turns it into a gemoetry object
feature = RGeo::GeoJSON.decode(str, json_parser: :json)
county_boundary = feature.geometry


saved_points = []

path = "#{dir}/points.csv"

if File.exist? path
  File.foreach(path) do |line|
    currentLat, currentLng = line.split(",")
    next if currentLat == "lat"
    saved_points.push({lat: currentLat.to_f, lng: currentLng.to_f})
  end
else
  # This opens the file and puts in a header 
  f = File.open(path, "w")
  f.puts "lat,lng"

  # This iterates through the points and adds a lat/lng pair
  # to the CSV for each point
  currentLat = minLat
  while currentLat <= maxLat
    currentLng = minLng
    while currentLng <= maxLng
      point = factory.point(currentLat,currentLng)
      if point.within?(county_boundary)
        f.puts "#{currentLng.round(7)},#{currentLat.round(7)}"
        saved_points.push({lng: currentLat.round(7), lat: currentLng.round(7)})
      end
      currentLng += lngOffset/2
    end
    currentLat += latOffset/2
  end

  # Clean up after yourself, says your mother.
  f.close
end
#--- 
def build_url(lat,lng,zoom=DEFAULT_ZOOM, size=IMAGE_SIZE)
  str = 'https://maps.googleapis.com/maps/api/staticmap?maptype=satellite&center='
  str << "#{lat},#{lng}&zoom=#{zoom}&size=#{size}x#{size+BOTTOM_CROP}&key=#{ENV['GMAPS_KEY']}"
  str
end

lookup = {}
label = JSON.parse(str)["properties"]["NAME"]

# THis breaks them into batches
saved_points.each_slice(CONCURRENT_DOWNLOADS) do |slices|
#saved_points[0..20].each_slice(CONCURRENT_DOWNLOADS) do |slices|
  requests = []
  slices.each do |item|
    lat = item[:lat]
    lng = item[:lng]
    url = build_url(lat,lng, DEFAULT_ZOOM)
    filename = "#{label}_#{lat}_#{lng}_z#{DEFAULT_ZOOM}.png"
    lookup[url] = filename
    unless File.exist? "#{dir}/#{filename}"
      request = Typhoeus::Request.new(url, {followlocation: true, timeout: 300})
      $hydra.queue(request)
      requests.push request
    else
      #puts "skipping #{filename}"
    end
  end

  ## DOWNLOAD 'EM
  $hydra.run

  ## SAVE THEM TO DISK
  responses = requests.map { |r|
    puts "#{r.url}: #{r.response.status_message}"
    if r.response.status_message == 'OK' &&  r.response.body.size > 5000
      File.open("#{dir}/#{lookup[r.url]}","wb") do |f|
        f.puts r.response.response_body
      end
    end
  }
  unless requests.empty?
    sleep(SLEEP_BETWEEN_DOWNLOADS)
  end
end

lookup.values.each do |filename|
  path = "#{dir}/#{filename}"
  if File.exist? path
    sizes = IO.read(path)[0x10..0x18].unpack('NN') # hack for getting sizes from the bytes of a PNG
    unless sizes[0] == IMAGE_SIZE && sizes[1] == IMAGE_SIZE
      `mogrify -gravity north -extent  #{IMAGE_SIZE}x#{IMAGE_SIZE} #{path}`
    end
  end
end