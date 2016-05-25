Download nodes
======

This folder contains one script that downloads 1000 nodes for a particular OSM category into a json file.

## How to run download_nodes.rb

Assuming you have set your environment variables in a .env file in the parent directory and that you have a features.csv file with the OSM categories to download, simply run

	ruby download_nodes/download_nodes.rb