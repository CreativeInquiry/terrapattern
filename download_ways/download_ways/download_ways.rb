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

NUM_TRIES = 10 

$hydra = Typhoeus::Hydra.new

#----------------------------------------------------------
#Download json with a thousand ways of a certain category
def get_json_from_openstreetmaps(key,val,constrain_to_usa = true)
  timeout = 20000
  bounds = "#{CONTINENTAL_US[:s]},#{CONTINENTAL_US[:w]},#{CONTINENTAL_US[:n]},#{CONTINENTAL_US[:e]}"
  bounds_string =  constrain_to_usa ? "(#{bounds})" : ""

  #This string fetches all geometry of a way including center points, but does not restrict how many ways to download
  #str = "data=[out:json][timeout:#{timeout}];way[\"#{key}\"=\"#{val}\"](#{bounds_string});foreach((._;>;);out center #{NUMBER_TO_DOWNLOAD};);"

  #This string fetches almost all geometry of a way except for center points. Does restrict number to download. 
  str = "data=[out:json][timeout:#{timeout}][maxsize:1073741824];way[\"#{key}\"=\"#{val}\"]#{bounds_string};out count;out meta geom #{NUMBER_TO_DOWNLOAD};"

  print str
  base_url = "http://overpass-api.de/api/interpreter?"
  url =  "#{base_url}#{URI.escape(str)}"
  puts url
  response = Typhoeus.get(url, {followlocation: true, timeout: timeout})
  response.body
end

def download_ways(key,val,label, zoom=DEFAULT_ZOOM, usa_only = true)

  # Make directory if it doesn't exist
  dir = "#{EXPORT_PATH}#{label}"
  FileUtils.mkdir_p(dir)

  tries = 0

  # Download the base JSON from openstreetmaps unless it exists
  json_path = "#{dir}/#{label}.json"
  json_content = "{}"
  if File.exist? json_path
    json_content = File.read(json_path)
  else
    json_content = get_json_from_openstreetmaps(key,val,usa_only)
    #continue with next tag if OSM timed out

    while (json_content.start_with?('<!DOCTYPE','<?xml') or json_content.empty?) and tries < NUM_TRIES do
      json_content = get_json_from_openstreetmaps(key,val,usa_only)
      tries = tries + 1
    end

    if(json_content.start_with?('<!DOCTYPE','<?xml')) 
      return
    else
      File.open(json_path, "w+") {|f| f.puts json_content}
    end
  end

end

CSV.foreach(CSV_FILE, headers: true) do |row|
  download_ways(row["key"],row["value"],row["label"],row["zoom"],row["usa only"])
end
