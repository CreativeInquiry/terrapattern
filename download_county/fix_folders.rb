require 'fileutils'

DEFAULT_ZOOM = 19
dir = "#{File.dirname(__FILE__)}/results"
path = "#{dir}/points.csv"
label = "Allegheny"
saved_points = []

File.foreach(path) do |line|
  currentLat, currentLng = line.split(",")
  next if currentLat == "lat"
  saved_points.push({lat: currentLat.to_f, lng: currentLng.to_f})
end


seen_lats = []
saved_points.each do |item|
  lat = item[:lat]
  lng = item[:lng]
  dirname = "#{dir}/#{lat.to_s.gsub(".","").gsub("-","")}"
   unless seen_lats.include? lat
    FileUtils.mkdir_p(dirname)
    saved_points.push lat
  end
  filename = "#{label}_#{lat}_#{lng}_z#{DEFAULT_ZOOM}.png"
  FileUtils.mv "#{dir}/#{filename}", "#{dirname}/#{filename}"
end