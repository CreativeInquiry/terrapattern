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
EXPORT_PATH = "#{File.dirname(__FILE__)}/training_set/"
CSV_FILE =    "#{File.dirname(__FILE__)}/features.csv";
IMAGE_SIZE = 256;
CONTINENTAL_US = {s: 24.9493, w: -125.0011, n: 49.5904, e: -66.9326}
DEFAULT_ZOOM = 18

$hydra = Typhoeus::Hydra.new

#----------------------------------------------------------
#Download json with a thousand ways of a certain category
def get_json_from_openstreetmaps(key,val,constrain_to_usa = true)
  timeout = 20000
  bounds = "#{CONTINENTAL_US[:s]},#{CONTINENTAL_US[:w]},#{CONTINENTAL_US[:n]},#{CONTINENTAL_US[:e]}"
  bounds_string =  constrain_to_usa ? "(#{bounds})" : ""
  str = "data=[out:json][timeout:#{timeout}];way[\"#{key}\"=\"#{val}\"]#{bounds_string};out skel qt #{NUMBER_TO_DOWNLOAD};"
  base_url = "http://overpass-api.de/api/interpreter?"
  url =  "#{base_url}#{URI.escape(str)}"
  response = Typhoeus.get(url, {followlocation: true, timeout: timeout})
  response.body
end

#----------------------------------------------------------
#Download the full geometry of a way
def get_geom_json_from_openstreetmaps(key,val,constrain_to_usa = true)
  timeout = 20000
  bounds_string =  constrain_to_usa ? "(#{bounds})" : ""
  bounds = "#{CONTINENTAL_US[:s]},#{CONTINENTAL_US[:w]},#{CONTINENTAL_US[:n]},#{CONTINENTAL_US[:e]}"
  str = "data=[out:json][timeout:#{timeout}];way(#{val});out geom;"
  base_url = "http://overpass-api.de/api/interpreter?"
  url =  "#{base_url}#{URI.escape(str)}"
  response = Typhoeus.get(url, {followlocation: true, timeout: timeout})
  response.body
end

#----------------------------------------------------------
#Download the center of a way
def get_center_json_from_openstreetmaps(key,val,constrain_to_usa = true)
  timeout = 20000
  bounds_string =  constrain_to_usa ? "(#{bounds})" : ""
  bounds = "#{CONTINENTAL_US[:s]},#{CONTINENTAL_US[:w]},#{CONTINENTAL_US[:n]},#{CONTINENTAL_US[:e]}"
  str = "data=[out:json][timeout:#{timeout}];way(#{val});out center;"
  base_url = "http://overpass-api.de/api/interpreter?"
  url =  "#{base_url}#{URI.escape(str)}"
  response = Typhoeus.get(url, {followlocation: true, timeout: timeout})
  response.body
end

#----------------------------------------------------------
def build_url(lat,lng,zoom=DEFAULT_ZOOM, size=IMAGE_SIZE)
  str = 'https://maps.googleapis.com/maps/api/staticmap?maptype=satellite&center='
  str << "#{lat},#{lng}&zoom=#{zoom}&size=#{size}x#{size+BOTTOM_CROP}&key=#{ENV['GMAPS_KEY']}"
  str
end

#----------------------------------------------------------
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
  end

  json_path_ways_full = "#{dir}/#{label}_ways.json"
  if File.exist? json_path_ways_full
    # Skip collecting centers/vectors if we've done it already  
    collected_ways = JSON.parse(File.read(json_path_ways_full))
  else
    # Get the list of elements
    elements = JSON.parse(json_content)["elements"]

    # Create an array of centers and vectors
    collected_ways = elements.collect do |item|

      ways_geom = get_geom_json_from_openstreetmaps("id",item["id"], usa_only)
      if(ways_geom.start_with?('<!DOCTYPE','<?xml')) 
        next
      end
      obj = JSON.parse(ways_geom)["elements"][0]

      ways_center = get_center_json_from_openstreetmaps("id",item["id"], usa_only)
      if(ways_center.start_with?('<!DOCTYPE','<?xml')) 
        next
      end
      obj[:center] = JSON.parse(ways_center)["elements"][0]["center"]

      # This is what will be returned from this closure and collected
      obj
    end.compact

    # Save it to disk
    File.open(json_path_ways_full, "w+") {|f| f.puts JSON.pretty_generate collected_ways}
  end

  # Get the images
  download_images(collected_ways, label, zoom)
end

#----------------------------------------------------------
def download_images(collected_ways, label, zoom)
  dir = "#{EXPORT_PATH}#{label}"

  lookup = {}

  # THis breaks them into batches
  collected_ways.each_slice(CONCURRENT_DOWNLOADS) do |slices|
    requests = []
    slices.each do |item|
      url = build_url(item["center"]["lat"],item["center"]["lon"], zoom)
      filename = "#{label}_#{item["id"]}_z#{DEFAULT_ZOOM}.png"
      lookup[url] = filename
      unless File.exist? "#{dir}/#{filename}"
        # $count++
        # exit if $count > 8000
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
end

#----------------------------------------------------------
CSV.foreach(CSV_FILE, headers: true) do |row|
  download_ways(row["key"],row["value"],row["label"],row["zoom"],row["us only"])
end
