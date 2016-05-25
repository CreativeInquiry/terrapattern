# Terrapattern
#### Golan Levin, David Newbury, and Kyle McDonald with Irene Alvarado, Aman Tiwari, and Manzil Zaheer

> Enabling journalists, citizen scientists, humanitarian workers and others to detect “patterns of interest” in satellite imagery through an open-source tool. 

---

###*These notes are out of date!*

The goal of this project is to provide researchers, journalists, citizen scientists, and artists the ability to quickly and easily scan extremely large geographical areas for specific visual features. In particular, we are interested in so-called "soft" features; things that do not appear on maps.  Examples might include methane blowholes, oil derricks, large fiberglass lumberjacks, or illegal farms. 

Our hope is that this will allow people who do not work for government intelligence agencies or large hedge funds the ability to research and answer questions about our world that are otherwise unknowable. For example, users could use the tool to identify destroyed buildings in conflict zones.

In this initial prototype, we intend to create a web interface that will allow web-savvy but non-expert users to visually identify examples of their desired feature on a map.  Given an example of a type of geographical feature, such as a baseball diamond, and once a desired geographical range has been established, for instance "Los Angeles", the computer will then begin an exhaustive search of that entire geographical area for those features.

## Wiki

Supplementary research is on the wiki.  Some things to look at include:

* [Imagery Comparison](https://github.com/workergnome/terrapattern/wiki/Satellite-Imagery-Information)

## Initial Steps

There are eight steps for this project: 

1. Identify features for the training set.
2. Build a neural net that is capable of identifying features in satellite photography.
3. Generate a lookup table of features and their locations.
4. Build a front-end that allows users to identify features and desired geographical ranges.
5. Design a back-end that can run these searches.
6. Notify the user that their search is complete.
7. Develop a front-end that allows a user to browse through their located instances.
8. Provide a interface for downloading the located features.

## Step 1:  Build the Training Set

A DCNN neural net needs to be trained on a set of tagged images.

This should to be delivered to him as a single directory, named `training_set`, containing (ideally) 1000 folders, each named with its respective tag as a singular noun.  If the name contains multiple words, they will be concatenated into a single word, such as `swimmingpool` or `dunkindonuts` (in ImageNet these categories are called "synsets").Each folder will contain (ideally) 1000 images of a satellite photograph containing an image of the entity described by the tag.

In terms of resolution and format: for reference, ImageNet is distributed as JPGs averaging 482x415 pixels with the full dataset of 1.2M images coming to 138GB. This is about 4.3 bits per pixel. Before training, a center crop of the images is taken and resized to 224x224 pixels. So for our purposes it might make sense to store the images as 256x256 JPGs that average 35Kb per image, and then at train time I will downsample them to 128x128 pixels.

Each of these images will be named with the tag name as well as the lat/lng combination of the image.  Each of these three datapoints will be separated by underscores. For example:

* My house, at lat: 40.481760, lng: -79.95402, would be recorded as `training_set/house/house_40.481760_-79.95402.jpg`
* The Emlenton Swimming Pool, at 41.181354, -79.704974 would be recorded as `training_set/swimmingpool/swimmingpool_41.181354_-79.704974.jpg`

The filenames themselves are not super important, it's not even essential for them to be unique across the whole dataset. It might be best if the filenames are just sequentially numbered -- and then any additional data can be stored in a csv/tsv or json file with all the metadata (category, filename, latitude, longitude, source). Or the key-value store described in the next section.

There will be one neural net per zoom level. To collect features at a different zoom level, we will need to train a different net.

Training one net on images from multiple sources will make it more robust, assuming they are at the same scale / zoom level. If they are not exactly at the same zoom level, it's fine to resample them until they are. This only works for downsampling, I have no confidence in upsampling.

If we have other channels besides red, green and blue (e.g., LANDSAT's 8 channels) then there are some interesting experiments we can try, but it may not be useful for the final tool. For example, we can try to predict the LANDSAT channels from the RGB image. Or we can predict LANDSAT channels along with a our feature vector (multimodal learning). We could also use it as an additional input to aid in prediction and feature generation, but if we don't have LANDSAT data for an area we cannot extract features. For me, working with RGB data alone is the first priority.

Ideally we can collect exactly 1000 images per category, but if we have more or less in some categories it's fine. For example ImageNet contains 732 to 1300 images per category. If we can only collect a small number of categories (e.g., 50) we should have significantly more images per category (e.g., 10,000 images of each category).


### Generating the Images

In order to generate these images, we need to identify **One Million Things**.  Each tag, or category, needs to be something that is:

* Visually distinctive
* Visible from above
* Large enough to be seen by satellite photography
* Should cover a significant portion of the image.
* Is not necessarily centered.

The steps needed to accomplish this are:

1. Find **many** lists of categories.
2. Generate a list of our 1000 categories.
3. Enter these into some sort of regular format/database/spreadsheet/csv/tsv/key-value store.
4. Extract/Scrape/Download many examples of each category as either address or lat/lng.
5. Enter *these* into our  regular format/database/spreadsheet/csv/tsv/key-value store
6. Convert each of theses that are an address into lat/lng
7. Convert each of these lat/lng pairs into a URL for an image
8. Scrape/API/Download all of the images.
9. Batch-process the urls into the correct folders (with the correct names).

As a first pass, we'll be using the [OpenStreetMap tag database](http://taginfo.openstreetmap.org) to identify categories.


## Step 2: Build a Neural Net

The current plan is to follow the research generated by ImageNet recognition. Recent networks that we can train include [VGG-16](http://arxiv.org/abs/1409.1556) and possibly [GoogLeNet](http://arxiv.org/abs/1409.4842) (but it has high memory constraints and it may require too much fiddling for not much reward).

There is a possibility that the features in satellite imagery do not correlate very well to the subjects of images from ImageNet. In this case we will have to think of it more as a segmentation problem, and we will train a different kind of model -- predicting pixel-labels from input images rather than a single label for the whole image.

## Step 3: Develop a Lookup

We create a hashtable of features and locations, so that the search will not need to actually re-process each image, but instead do something more efficient.  

## Step 4: Create a UI for identifying features and ranges

We allow the user to identify their initial search item. This is done through a combination of a map interface, address search, and a drawing tool—either a "paint over the area that's interesting to you" or "draw a box around the area that's interesting to you". 

Once they've done that, we should allow them to set a search boundary for their full search.  We could either do that via text: "North America", "Pennsylvania", "Allegheny County" or via "Draw a box/polygon around your desired region".

## Step 5: Develop the Backend for searching

For the prototype, how robust does this need to be?  DO we need to handle queuing jobs?  Does this need to be automated *at all*, or is "Kyle gets an email and kicks off the job via ssh" sufficient?

How do we know when a search is completed?  

## Step 6: Notify the user

How should we do so?  Email is probably the easiest.  Do we want to have user accounts?  Do we need this for the prototype?

## Step 7: Browse the results

Do we need to provide the user with the ability to check in and see what progress has been made on their job?

Do we need a refine stage in here, where they filter through the initial results and refine for a more granular search?

Golan, I know that you've talked about adding additional tools to the result set.  Is that part of this prototype?  What are you thinking for that?

## Step 8: Download your Data

What are appropriate formats for downloading this data?  CSV?  JSON?  GEOJSON?  A directory of images?

How long do we plan on keeping an individual's results?  Are the results public?  Do we want to give people the option to *make* their results public?

# Running the lookup server

The lookup server lives on the Digits1 machine:

1. `~/Documents/server.py`: the lookup server
2. `~/Documents/level19/<city_name>_features_z19.t7`: the "descriptor" vectors (stored in torch format)
3. `~/Documents/level19/<city_name>_z19.txt`: the filenames associated with each vector in the `*.t7` file.

#### To run it locally:

1. Go to the Jupyter interface
2. Create a new terminal by New>Terminal
3. `cd Documents`
4. `python server.py`
5. After ~3 minutes (60 seconds per city) the ball trees will be completed and the server will be running.

To check on the lookup server:

1. Go to the Jupyter interface
2. Find the terminal the server is running in in the Terminals tab.

#### To run it in the cloud:

1. SSH into the cloud server (you need to have set up your SSH RSA keys on the server for this!)
2. If not already the terrapattern user, `su - terrapattern` with the correct password as the password (you need to have had a valid private key to get this far, so the security of this step doesn't really matter).
3. You should now be in a Byobu session. Press `Ctrl-A` and then `<an arrow key>` to naviage through the panes.
4. Go to the pane the server was previously running in (probably has an error message or something like ... ?GET= <city_name> .. in it)
4. `cd ~`
5. `python server.py`

To check on the lookup server:

1. SSH into the cloud server (you need to have set up your SSH RSA keys on the server for this!)
2. If not already the terrapattern user, `su - terrapattern` with the correct password as the password (you need to have had a valid private key to get this far, so the security of this step doesn't really matter).
3. To check resource consumption, type `htop` in a free pane (or press `Ctrl-A` and then `%` or `"` to make a new one)
4. Press `Ctrl-C` to exit `htop` and `Ctrl-D` to kill the pane you made.
5. Press `Ctrl-A` and then `d` to exit.
6. `logout` 
