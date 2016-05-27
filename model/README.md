### Extract Features
----
Use `extract_features.lua` to run a trained model over a set of images and save the feature vectors generated. 

###### To use
1. Make a file list of the image files `ls image-folder > image-filenames.txt`
2. `th extract_features.lua path/to/model.t7 image-filenames.txt path/to/images-folder output-filename.t7`

### NYC Demo IPyNB
----
This IPython notebook contains a demo of how to load the saved features, match them up to filenames and use a ball tree to efficiently find nearest-neighbors.

### Datasets
----
These allow you to work with the terrapattern or a terrapattern like (i.e satellite imagery) dataset. `datasets/terrapattern.lua` contains colour normalisation data computed from a random subset of terrapattern images. 
