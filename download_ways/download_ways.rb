require 'dotenv'
Dotenv.load

require 'typhoeus'
require 'json'
require 'uri'
require 'fileutils'
require 'csv'


NUMBER_TO_DOWNLOAD = 1000 #number of ways per category to download
CONCURRENT_DOWNLOADS = 100
SLEEP_BETWEEN_DOWNLOADS = 0
BOTTOM_CROP = 23;
EXPORT_PATH = "training_set/"
IMAGE_SIZE = 256;
CONTINENTAL_US = {s: 24.9493, w: -125.0011, n: 49.5904, e: -66.9326}
DEFAULT_ZOOM = 18

NUM_TRIES = 10 #number of times to try to download OSM geometry and OSM centers

$hydra = Typhoeus::Hydra.new

#----------------------------------------------------------
#Download json with a thousand ways of a certain category
def get_json_from_openstreetmaps(key,val,constrain_to_usa = true)
  timeout = 10000
  bounds = "#{CONTINENTAL_US[:s]},#{CONTINENTAL_US[:w]},#{CONTINENTAL_US[:n]},#{CONTINENTAL_US[:e]}"
  bounds_string =  constrain_to_usa ? "(#{bounds})" : ""
  str = "data=[out:json][timeout:#{timeout}];way[\"#{key}\"=\"#{val}\"]#{bounds_string};out skel qt #{NUMBER_TO_DOWNLOAD};"
  base_url = "http://overpass-api.de/api/interpreter?"
  url =  "#{base_url}#{URI.escape(str)}"
  puts url
  response = Typhoeus.get(url, {followlocation: true, timeout: timeout})
  response.body
end

#----------------------------------------------------------
#Download the full geometry of a way
def get_geom_json_from_openstreetmaps(key,val,constrain_to_usa = true)
  timeout = 1000
  bounds_string =  constrain_to_usa ? "(#{bounds})" : ""
  bounds = "#{CONTINENTAL_US[:s]},#{CONTINENTAL_US[:w]},#{CONTINENTAL_US[:n]},#{CONTINENTAL_US[:e]}"
  #str = "data=[out:json][timeout:#{timeout}];(way(#{val});>;);out center;"
  str = "data=[out:json][timeout:#{timeout}];way(#{val});out geom;"
  #print str 
  base_url = "http://overpass-api.de/api/interpreter?"
  url =  "#{base_url}#{URI.escape(str)}"
  puts url #only outputing one url for speed
  response = Typhoeus.get(url, {followlocation: true, timeout: timeout})
  response.body
end

#----------------------------------------------------------
#Download the center of a way
def get_center_json_from_openstreetmaps(key,val,constrain_to_usa = true)
  timeout = 1000
  bounds_string =  constrain_to_usa ? "(#{bounds})" : ""
  bounds = "#{CONTINENTAL_US[:s]},#{CONTINENTAL_US[:w]},#{CONTINENTAL_US[:n]},#{CONTINENTAL_US[:e]}"
  #str = "data=[out:json][timeout:#{timeout}];(way(#{val});>;);out center;"
  str = "data=[out:json][timeout:#{timeout}];way(#{val});out center;"
  #print str 
  base_url = "http://overpass-api.de/api/interpreter?"
  url =  "#{base_url}#{URI.escape(str)}"
  #puts url
  response = Typhoeus.get(url, {followlocation: true, timeout: timeout})
  response.body
end


def build_url(lat,lng,zoom=DEFAULT_ZOOM, size=IMAGE_SIZE)
  str = 'https://maps.googleapis.com/maps/api/staticmap?maptype=satellite&center='
  str << "#{lat},#{lng}&zoom=#{zoom}&size=#{size}x#{size+BOTTOM_CROP}&key=#{ENV['GMAPS_KEY']}"
  str
end

def download_ways(key,val,label, zoom=DEFAULT_ZOOM, usa_only = true)

  # Make directory if it doesn't exist
  dir = "#{EXPORT_PATH}#{label}"
  FileUtils.mkdir_p(dir)

  # Download the base JSON from openstreetmaps unless it exists
  json_path = "#{dir}/#{label}.json"
  json_content = "{}"
  if File.exist? json_path
    json_content = File.read(json_path)
  else
    json_content = get_json_from_openstreetmaps(key,val,usa_only)
    File.open(json_path, "w+") {|f| f.puts json_content}
  end

  #continue with next tag if OSM timed out
  if(json_content.start_with?('<!DOCTYPE','<?xml')) 
    return
  else
    # Get the list of elements
    elements = JSON.parse(json_content)["elements"]
    complete_elements = elements
  end

  way = 0

  # This breaks them into batches
  elements.each_slice(CONCURRENT_DOWNLOADS) do |slices|
    requests = []

    slices.each do |item|
      url = build_url(item["lat"],item["lon"], zoom)
      filename = "#{label}_#{item["lat"]}_#{item["lon"]}.png"
      lookup[url] = filename

        # Only try to download the geometry for a way 10 times from OSM. 
        #If that doesn't work, then go on to the next label
        tries = 1 
         ways_geom = get_geom_json_from_openstreetmaps("id",item["id"], usa_only)
         while (ways_geom.start_with?('<!DOCTYPE','<?xml') && tries <= NUM_TRIES) do
          ways_geom = get_geom_json_from_openstreetmaps("id",item["id"], usa_only)
          print "WAYS_GEOM ", ways_geom, "\n"
          tries = tries + 1 
        end

        if(ways_geom.start_with?('<!DOCTYPE','<?xml') or ways_geom.empty?) 
          print "FAILED: Geometry #{dir}/#{label}"
          return
        else
          geom = JSON.parse(ways_geom)["elements"][0]
        end

        # Only try to download the center for a way 10 times from OSM. 
        #If that doesn't work, then go on to the next label
       tries = 1 
         ways_center = get_center_json_from_openstreetmaps("id",item["id"], usa_only)
         while (ways_center.start_with?('<!DOCTYPE','<?xml') && tries <= NUM_TRIES) do
          ways_center = get_center_json_from_openstreetmaps("id",item["id"], usa_only)
          tries = tries + 1 
       end

       if(ways_center.start_with?('<!DOCTYPE','<?xml') or ways_center.empty?) 
          print "FAILED: Center #{dir}/#{label}"
          return
        else
          center = JSON.parse(ways_center)["elements"][0]["center"]         
        end

      geom["center"] = center
      complete_elements[way] = geom         
      way = way + 1 
    end
  end

  #puts JSON.pretty_generate elements
  json_path_ways_full = "#{dir}/#{label}_ways.json"
  File.open(json_path_ways_full, "w+") {|f| f.puts JSON.pretty_generate complete_elements}

end

CSV.foreach("features.csv", headers: true) do |row|
  download_ways(row["key"],row["value"],row["label"],row["zoom"],row["us only"])
end
