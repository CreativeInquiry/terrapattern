### ResNet
----
We used a 34-layer ResNet, [implemented by Facebook](https://github.com/facebook/fb.resnet.torch). This was trained for ~4 days, using a single NVIDIA GTX-980. The final top-5 error on the validation set reached was **25.609%** and the final top-1 error was **49.201**.

### NYC Demo IPyNB
----
This IPython notebook contains a demo of how to load the saved features, match them up to filenames and use a ball tree to efficiently find nearest-neighbors.

### Datasets
----
These allow you to work with the terrapattern or a terrapattern like (i.e satellite imagery) dataset. `datasets/terrapattern.lua` contains colour normalisation data computed from a random subset of terrapattern images. 
