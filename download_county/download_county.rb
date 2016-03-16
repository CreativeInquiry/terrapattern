require 'rgeo'
require 'rgeo/geo_json'
require 'json'
require 'typhoeus'
require 'dotenv'
require 'uri'
require 'fileutils'

Dotenv.load


BOTTOM_CROP = 23
IMAGE_SIZE = 256
DEFAULT_ZOOM = 18
CONCURRENT_DOWNLOADS = 100
SLEEP_BETWEEN_DOWNLOADS = 0
dir = "#{File.dirname(__FILE__)}/results"
FileUtils.mkdir_p(dir)

$hydra = Typhoeus::Hydra.new


# This is just a heredoc for a geo-json file of the boundary of allegheny county.
str = <<GEOJSON
{
  "type": "Feature",
  "properties": {
    "GEO_ID": "0500000US42003",
    "STATE": "42",
    "COUNTY": "003",
    "NAME": "Allegheny",
    "LSAD": "County",
    "CENSUSAREA": 730.075000
  },
  "geometry": {
    "type": "Polygon",
    "coordinates": [
      [
        [
          -79.722151,
          40.409098
        ],
        [
          -79.771184,
          40.374938
        ],
        [
          -79.772160,
          40.369391
        ],
        [
          -79.774412,
          40.359673
        ],
        [
          -79.781851,
          40.323845
        ],
        [
          -79.782114,
          40.322769
        ],
        [
          -79.782300,
          40.321526
        ],
        [
          -79.783684,
          40.315913
        ],
        [
          -79.775139,
          40.287888
        ],
        [
          -79.794715,
          40.281683
        ],
        [
          -79.788015,
          40.261300
        ],
        [
          -79.805748,
          40.240595
        ],
        [
          -79.781761,
          40.227711
        ],
        [
          -79.870585,
          40.197415
        ],
        [
          -79.881913,
          40.196519
        ],
        [
          -79.888986,
          40.194823
        ],
        [
          -79.893281,
          40.194352
        ],
        [
          -79.896448,
          40.194481
        ],
        [
          -79.900246,
          40.195095
        ],
        [
          -79.956073,
          40.213582
        ],
        [
          -79.970652,
          40.231814
        ],
        [
          -79.952098,
          40.240877
        ],
        [
          -79.914139,
          40.252518
        ],
        [
          -80.033712,
          40.288034
        ],
        [
          -80.183466,
          40.332777
        ],
        [
          -80.360873,
          40.477539
        ],
        [
          -80.360782,
          40.477604
        ],
        [
          -80.228579,
          40.573072
        ],
        [
          -80.180070,
          40.609418
        ],
        [
          -80.144850,
          40.613474
        ],
        [
          -80.148451,
          40.674290
        ],
        [
          -79.692930,
          40.669744
        ],
        [
          -79.692587,
          40.669732
        ],
        [
          -79.688777,
          40.644385
        ],
        [
          -79.721270,
          40.607966
        ],
        [
          -79.763770,
          40.592966
        ],
        [
          -79.774370,
          40.569767
        ],
        [
          -79.765415,
          40.549854
        ],
        [
          -79.722387,
          40.542043
        ],
        [
          -79.701624,
          40.525449
        ],
        [
          -79.701985,
          40.523787
        ],
        [
          -79.703834,
          40.443526
        ],
        [
          -79.722151,
          40.409098
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
  minLat = lat if lat < minLat
  maxLng = lng if lng > maxLng
  minLng = lng if lng < minLng
end

## This is a rough estimate of the number of pixels at zoom level 18.
#  Note that can never remember which is LAT and which is LNG.
lngOffset = 0.001045
latOffset = 0.001373


# This is the silly Java-ish initialization for the geography engine
factory = ::RGeo::Geos.factory

# This parses the geoJSON and turns it into a gemoetry object
feature = RGeo::GeoJSON.decode(str, json_parser: :json)
county_boundary = feature.geometry

# This opens the file and puts in a header 
f = File.open("#{dir}/points.csv", "w")
f.puts "lat,lng"

# This iterates through the points and adds a lat/lng pair
# to the CSV for each point

saved_points = []

currentLat = minLat
while currentLat <= maxLat
  currentLng = minLng
  while currentLng <= maxLng
    point = factory.point(currentLat,currentLng)
      if point.within?(county_boundary)
        f.puts "#{currentLng},#{currentLat}"
        saved_points.push({lng: currentLat, lat: currentLng})
      end
    currentLng += lngOffset
  end
  currentLat += latOffset
end

# Clean up after yourself, says your mother.
f.close

#--- 
def build_url(lat,lng,zoom=DEFAULT_ZOOM, size=IMAGE_SIZE)
  str = 'https://maps.googleapis.com/maps/api/staticmap?maptype=satellite&center='
  str << "#{lat},#{lng}&zoom=#{zoom}&size=#{size}x#{size+BOTTOM_CROP}&key=#{ENV['GMAPS_KEY']}"
  str
end

lookup = {}
label = JSON.parse(str)["properties"]["NAME"]

# THis breaks them into batches
saved_points[0..20].each_slice(CONCURRENT_DOWNLOADS) do |slices|
  requests = []
  slices.each do |item|
    url = build_url(item[:lat],item[:lng], DEFAULT_ZOOM)
    filename = "#{label}_#{item[:lat]}_#{item[:lng]}_z#{DEFAULT_ZOOM}.png"
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
