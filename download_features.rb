require 'dotenv'
Dotenv.load

require 'typhoeus'
require 'json'
require 'uri'
require 'fileutils'


CONCURRENT_DOWNLOADS = 100
SLEEP_BETWEEN_DOWNLOADS = 0
BOTTOM_CROP = 23;
EXPORT_PATH = "training_set/"
IMAGE_SIZE = 256;
CONTINENTAL_US = {s: 24.9493, w: -125.0011, n: 49.5904, e: -66.9326}
DEFAULT_ZOOM = 18

def get_json_from_openstreetmaps(key,val)
  timeout = 600
  bounds = "#{CONTINENTAL_US[:s]},#{CONTINENTAL_US[:w]},#{CONTINENTAL_US[:n]},#{CONTINENTAL_US[:e]}"
  str = "data=[out:json][timeout:#{timeout}];node[\"#{key}\"=\"#{val}\"](#{bounds});out skel qt 1000;"
  base_url = "http://overpass-api.de/api/interpreter?"
  url =  "#{base_url}#{URI.escape(str)}"
  response = Typhoeus.get(url, {followlocation: true, timeout: timeout})
  response.body
end

def build_url(lat,lng,zoom=DEFAULT_ZOOM, size=IMAGE_SIZE)
  str = 'https://maps.googleapis.com/maps/api/staticmap?maptype=satellite&center='
  str << "#{lat},#{lng}&zoom=#{zoom}&size=#{size}x#{size+BOTTOM_CROP}&key=#{ENV['GMAPS_KEY']}"
  str
end

def download_images(key,val,label, zoom=DEFAULT_ZOOM)

  dir = "#{EXPORT_PATH}#{label}"
  FileUtils.mkdir_p(dir)

  json_path = "#{dir}/#{label}.json"
  json_content = "{}"
  if File.exist? json_path
    json_content = File.read(json_path)
  else
    json_content = get_json_from_openstreetmaps(key,val)
    File.open(json_path, "w+") {|f| f.puts json_content}
  end
  elements = JSON.parse(json_content)["elements"]

  hydra = Typhoeus::Hydra.new
  lookup = {}
  elements.each_slice(CONCURRENT_DOWNLOADS) do |slices|
    requests = []
    slices.each do |item|
      url = build_url(item["lat"],item["lon"], zoom)
      filename = "#{label}_#{item["lat"]}_#{item["lon"]}.png"
      lookup[url] = filename
      unless File.exist? "#{dir}/#{filename}"
        request = Typhoeus::Request.new(url, {followlocation: true, timeout: 300})
        hydra.queue(request)
        requests.push request
      else
        #puts "skipping #{filename}"
      end
    end

    ## DOWNLOAD 'EM
    hydra.run

    ## SAVE THEM TO DISK
    responses = requests.map { |r|
      puts "#{r.url}: #{r.response.status_message}"
      if r.response.status_message == 'OK'
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
    sizes = IO.read(path)[0x10..0x18].unpack('NN') # hack for getting sizes from the bytes of a PNG
    unless sizes[0] == IMAGE_SIZE && sizes[1] == IMAGE_SIZE
      `mogrify -gravity north -extent  #{IMAGE_SIZE}x#{IMAGE_SIZE} #{path}`
    end
  end
end

download_images("leisure", "swimming_pool", "swimming_pool", 18)