# Terrapattern
##### Golan Levin, Kyle McDonald & David Newbury

> Enabling journalists, citizen scientists, humanitarian workers and others to detect “patterns of interest” in satellite imagery through an open-source tool. 

---

The goal of this project is to provide researchers, journalists, citizen scientists, and artists the ability to quickly and easily scan extremely large geographical areas for specific visual features. In particular, we are interested in so-called "soft" features; things that do not appear on maps.  Examples might include methane blowholes, oil derricks, large fiberglass lumberjacks, or illegal farms. 

Our hope is that this will allow people who do not work for government intelligence agencies or large hedge funds the ability to research and answer questions about our world that are otherwise unknowable. For example, users could use the tool to identify destroyed buildings in conflict zones.

In this initial prototype, we intend to create a web interface that will allow web-savvy but non-expert users to visually identify examples of their desired feature on a map.  Once approximately 10 to 20 examples of a type of geographical feature have been located, for instance 20 different swimming pools, and once a desired geographical range has been established, for instance "Los Angeles", the computer will then begin an exhaustive search of that entire geographical area for those features.  We expect that this will take some time: several hours, but less than a day. When the computer has completed its search it will notify the user and provide them with a list of images and latitude longitude coordinates for each found feature.

*(Golan, feel free to add more stuff here, and correct what I've written.)*

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

Kyle is our neural network trainer <small>(I am imagining him in a set of high black boots and a whip)</small> and will be writing some sort of magical code that will use math and such things to detect things that we cannot begin to describe.  This neural net needs to be trained on a set of tagged images.

Kyle has asked for this to be delivered to him as a single directory, named `training_set`, containing 1000 folders, each named with its respective tag as a singular noun.  If the name contains multiple words, they will be concatenated into a single word, such as `swimmingpool` or `dunkindonuts` (in ImageNet these categories are called "synsets").Each folder will contain 1000 images of a satellite photograph containing an image of the entity described by the tag.

In terms of resolution and format: for reference, ImageNet is distributed as JPGs averaging 482x415 pixels with the full dataset of 1.2M images coming to 138GB. This is about 4.3 bits per pixel. Before training, a center crop of the images is taken and resized to 224x224 pixels. So for our purposes it might make sense to store the images as 256x256 JPGs that average 35Kb per image, and then at train time I will downsample them to 128x128 pixels.

Each of these images will be named with the tag name as well as the lat/lng combination of the image.  Each of these three datapoints will be separated by underscores. For example:

* My house, at lat: 40.481760, lng: -79.95402, would be recorded as `training_set/house/house_40.481760_-79.95402.jpg`
* The Emlenton Swimming Pool, at 41.181354, -79.704974 would be recorded as `training_set/swimmingpool/swimmingpool_41.181354_-79.704974.jpg`

The filenames themselves are not super important, it's not even essential for them to be unique across the whole dataset. It might be best if the filenames are just sequentially numbered -- and then any additional data can be stored in a csv/tsv or json file with all the metadata (category, filename, latitude, longitude, source). Or the key-value store described in the next section.

There will be one neural net per zoom level. To collect features at a different zoom level, we will need to train a different net.

Training one net on images from multiple sources will make it more robust, assuming they are at the same scale / zoom level. If they are not exactly at the same zoom level, it's fine to resample them until they are. This only works for downsampling, I have no confidence in upsampling.

If we have other channels besides red, green and blue (e.g., LANDSAT's 8 channels) then there are some interesting experiments we can try, but it may not be useful for the final tool. For example, we can try to predict the LANDSAT channels from the RGB image. Or we can predict LANDSAT channels along with a our feature vector (multimodal learning). We could also use it as an additional input to aid in prediction and feature generation, but if we don't have LANDSAT data for an area we cannot extract features. For me, working with RGB data alone is the first priority.

Ideally we can collect exactly 1000 images per category, but if we have more or less in some categories it's fine. For example ImageNet contains 732 to 1300 images per category. If we can only collect a small number of categories (e.g., 50) we should have significantly more images per category (e.g., 10,000 images of each category).

Current OSM tags being used are here: <https://docs.google.com/spreadsheets/d/1y43HYDqW6a9f802u2Hktrq2aVldmf3kfvYjfsGtIzyE/edit?usp=sharing>

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

As a first pass, we'll be using the [OpenStreetMap tag database](http://taginfo.openstreetmap.org) to identify categories. [Golan's Google Doc](https://docs.google.com/document/d/1irIj0IAYqNLGLORUGB1ho1vDrHj66zPUjlsG21C_Q9Q/edit?ts=5649f797) has other options.

## Step 2: Build a Neural Net

The current plan is to follow the research generated by ImageNet recognition. Recent networks that we can train include [VGG-16](http://arxiv.org/abs/1409.1556) and possibly [GoogLeNet](http://arxiv.org/abs/1409.4842) (but it has high memory constraints and it may require too much fiddling for not much reward).

There is a possibility that the features in satellite imagery do not correlate very well to the subjects of images from ImageNet. In this case we will have to think of it more as a segmentation problem, and we will train a different kind of model -- predicting pixel-labels from input images rather than a single label for the whole image.

## Step 3: Develop a Lookup

Kyle, you and I should work together on this, if only to develop a "contract" for how we will interface here.  If I remember correctly from our dinner together, the idea here is to create a hashtable of features and locations, so that the search will not need to actually re-process each image, but instead do something more efficient.  

Would the most appropriate way for this to work be for me the front-end to provide a set of square images, like the ones we're doing feature detection on?  a set of lat/lng pairs?  a geographical boundary of the perimeter of the region of interest? 

## Step 4: Create a UI for identifying features and ranges

Golan, we should define exactly what we think that people will do here.

My thoughts are that we would begin by allowing the user to create an account.  Unless the prototype is entirely designed to be used by *us*, we're going to need a way to notify people in not-real-time, so we're going to have to both email people and distinguish between potential users when we present their results.  

The next step will be to allow the user to identify their initial search items.  This is probably best done through a combination of a map interface, address search, and a drawing tool—either a "paint over the area that's interesting to you" or "draw a box around the area that's interesting to you".

They'll have to do this 10-20 times, so we're going to need a way to save a queue of these in a job.  Individuals may need have multiple jobs, so we're going to need a way to associate what they're doing with a particular job out of their collection of jobs.  

Once they've done this, we should probably make sure that the items they've selected share some set of similarities.  *(Kyle, is this possible?  Is this useful?)*  

Once they've done that, we should allow them to set a search boundary for their full search.  We could either do that via text: "North America", "Pennsylvania", "Allegheny County" or via "Draw a box/polygon around your desired region".

Finally, we should allow them to submit a job.  Hopefully, we can give them an idea of how long this will take.

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