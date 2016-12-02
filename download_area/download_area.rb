# Example code for about 800 square miles around Miami

require 'rgeo'
require 'rgeo/geo_json'
require 'json'
require 'typhoeus'
require 'dotenv'
require 'uri'
require 'fileutils'

Dotenv.load

# Adjust for different zoom levels
#DEFAULT_ZOOM = 18 
#lngOffset = 0.001707 #Calculated for latitude 25.769322
#latOffset = 0.001373
DEFAULT_ZOOM = 19
lngOffset = 0.000853 #Calculated for latitude 25.769322
latOffset = 0.000686

dir = "#{File.dirname(__FILE__)}/results" # Directory to save a csv file with all the lat lon points to download tiles for
BOTTOM_CROP = 23
IMAGE_SIZE = 256
CONCURRENT_DOWNLOADS = 100
SLEEP_BETWEEN_DOWNLOADS = 0

FileUtils.mkdir_p(dir)

$hydra = Typhoeus::Hydra.new


# Adjust this geojson section to represent the bounding box for area to download
str = <<GEOJSON
{
  "type": "Feature",
  "properties": {
    "NAME": "Miami"
  },
  "geometry": {
    "type": "Polygon",
    "coordinates": [
      [
        [
          -80.37460327148438,
          26.154205294151907
        ],
        [
          -80.30593872070311,
          26.22444694563432
        ],
        [
          -80.068359375,
          26.220751072791945
        ],
        [
          -80.101318359375,
          25.961748853879143
        ],
        [
          -80.09857177734375,
          25.77887050485261
        ],
        [
          -80.145263671875,
          25.64647846279615
        ],
        [
          -80.16448974609375,
          25.61304787081554
        ],
        [
          -80.22628784179688,
          25.65761991333506
        ],
        [
          -80.26336669921875,
          25.601902261115754
        ],
        [
          -80.51742553710938,
          25.70959958489245
        ],
        [
          -80.50643920898438,
          25.91482062206972
        ],
        [
          -80.45974731445312,
          25.96915686519401
        ],
        [
          -80.46524047851562,
          26.048146607649734
        ],
        [
          -80.48309326171875,
          26.085154746196096
        ],
        [
          -80.47760009765624,
          26.177623883345746
        ],
        [
          -80.38284301757812,
          26.154205294151907
        ],
        [
          -80.37460327148438,
          26.154205294151907
        ]
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
  raise("No URL Defined")
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

  ## DOWNLOAD THE MAP TILES
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