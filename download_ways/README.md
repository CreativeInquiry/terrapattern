Download ways data and visualize them on a map
======

This folder contains two main scripts: one that downloads 1000 ways for a particular OSM category into a json file and another script that helps you visualize where those ways are located across a map. 


## Folder structure


```
download_ways/
  download_ways/			--> contains script to download ways data
    all_ways_features 		--> a list of all the way categories that can be used
    features.csv			--> a list of way categories to be used for download_ways.rb script
    download_ways.rb	
    training_data/			--> can be empty. For running the download_ways.rb script
  data/		        
  	less500/				--> stores JSONs for categories with more than 500 ways in the U.S. 
  	more500/				--> stores JSONs for categories with less than 500 ways in the U.S. 
  visualize_ways_map/		--> to view the perimiter of each way and its location you can use a simple webpage waysmapview.html       
  	L.Map.Deflate.js				
  	waysmapview.html		--> map to view locations and perimiter of ways
```

## How to run download_ways.rb

Assuming you have set your environment variables in a .env file in the parent directory and that you have a features.csv file with the OSM categories to download, simply run

	ruby download_ways/download_ways/download_ways.rb

## How to run visualize_ways_map
* The way JSON files (the data) must be in a folder called "data/more1000".
* Run a server from the root directory (from download_ways). If not, the map page won't be able to access the "data/more1000" folder. 
* Just zoom out the map the first time you load the page

<br>
<img src="visualize_ways_map/map1.png" width="700px">
<br><br>
<img src="visualize_ways_map/map2.png" width="700px">