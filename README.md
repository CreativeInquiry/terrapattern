# Terrapattern
#### Golan Levin, Kyle McDonald & David Newbury

Enabling journalists, citizen scientists, humanitarian workers and others to detect “patterns of interest” in satellite imagery through an open-source tool. 

The goal of this project is to provide researchers, journalists, citizen scientists, and artists the ability to quickly and easily scan extremely geographical areas for specific visual features. In particular, we are interested in so-called "soft" features; things that do not appear on maps.  Examples might include methane blowholes, oil derricks, large fiberglass lumberjacks, or illegal farms. 

For example, users could use the tool to identify destroyed buildings in conflict zones.

We intend to create a web interface for this project that will allow web-savvy but non-expert users to identify examples of their desired feature on a map.  Once a small number of examples have been located, (~10-20 instances) and a desired geographical range has been established, the computer will then begin an exhaustive search of the entire area for those features.  We expect that this will take some time—on the order of hours. Once the computer has completed its search, it will notify the user, and provide them with a list of images and lat/lng pair for each found instance.

*(Golan, feel free to add more stuff here, and correct what I've written.)*

## Initial Steps

There are eight steps for this project: 

1. Identify features for the training set.
2. Build a neural net that is capable of identifying features in satellite photography.
3. Generate a lookup table of features and their locations
4. Build a front-end that allows users to identify features and desired geographical ranges
5. Design a back-end that can run these searches
7. Develop a front-end that allows a user to browse through their located instances
8. Provide a interface for downloading the located features.

## Step 1:  Build the Training Set

Kyle is our neural network trainer <small>(I am imagining him in a set of high black boots and a whip)</small> and will be writing some sort of magical code that will use math and such things to detect things that we cannot begin to describe.  *(Kyle, feel free to elaborate or clarify as needed.)*  This theoretical neural net needs to be trained on a set of tagged images.

Kyle has asked for this to be delivered to him as a single directory, named `training_set`, containing 1000 folders, each named with its respective tag as a singular noun.  If the name contains multiple words, they will be concatinated into a single word, such as `swimmingpool` or `dunkindonuts`.Each folder will contain 1000 images of a satellite photograph containing an image of the entity described by the tag.

Each of these images will be a square 100px by 100px jpeg, compressed at 80%.  *(Kyle, please correct this spec with actual information).*

Each of these images will be named with the lat/lng combination of the image as well as the tag name.  Each of these three datapoints will be separated by underscores. For example:  

* My house, at lat: 40.481760, lng: -79.95402, would be recorded as `training_set/house/40.481760_-79.95402_house.jpg`
* The Emlenton Swimming Pool, at 41.181354, -79.704974 would be recorded as `training_set/swimmingpool/41.181354_-79.704974_swimmingpool.jpg`

*(Kyle, do we also want to distinguish these by source?  i.e., which service provided the image?  How about by zoom level?)*

*(Kyle, what do we do if we have less that 1000 examples?  what do we do if we have more than 1000 examples?)*

### Generating the Images

In order to generate these images, we need to identify **One Million Things**.  Each tag, or category, needs to be something that is:

* Visually distinctive
* Visible from above
* Large enough to be seen by satellite photography
* *Are there other constraints?*

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

Kyle, this is your baby.  I don't know enough to start here.

## Step 3: Develop a Lookup

Kyle, you and I should work together on this, if only to develop a "contract" for how we will interface here.

## Step 4: Create a UI for identifying features and ranges

Golan, we should define exactly what we think that people will do here.

## Step 5: Develop the Backend for searching

For the prototype, how robust does this need to be?  DO we need to handle queueing jobs?  Does this need to be automated *at all*, or is "Kyle gets an email and kicks off the job via ssh" sufficient?

## Step 6: Notify the user

How should we do so?  Email is probably the easiest.  Do we want to have user accounts?  Do we need this for the prototype?

## Step 7: Browse the results

Do we need a refine stage in here? 

## Step 8: Download your Data

What are appropriate formats for downloading this data?  CSV?  JSON?  GEOJSON?  A directory of images?