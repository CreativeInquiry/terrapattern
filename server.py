#!/usr/bin/env python

from os.path import basename, isfile
from scipy.spatial.distance import cdist, euclidean
from flask import Flask, request
import numpy as np
import json
import time
import cPickle
import torchfile
from sklearn.neighbors import NearestNeighbors
from sklearn.decomposition import PCA, FastICA
from sklearn.manifold import TSNE

print 'Loading feature vectors.'
features_filenames = {('Allegheny', 19) : 'level19/Allegheny_z19_features.t7',
                      ('New_York' , 19) : 'level19/New_York_z19_features.t7',
                      ('San_Fran' , 19) : 'level19/San_Fran_z19_features.t7',
		      ('Detroit'  , 19) : 'level19/Detroit_z19_features.t7'}
all_features = {region_level : torchfile.load(features_filenames[region_level]) \
                for region_level in features_filenames}


def get_lat_long(filename):
    return (float(filename.split("_")[1]), float(filename.split("_")[2]))

print 'Loading filenames.'
tile_filenames = {('Allegheny', 19) : 'level19/Allegheny_z19.txt',
                  ('New_York' , 19) : 'level19/New_York_z19.txt',
                  ('San_Fran' , 19) : 'level19/San_Fran_z19.txt',
		  ('Detroit'  , 19) : 'level19/Detroit_z19.txt'}

# dict of filename : (filename idx, (lat, long))
tile_dicts = {}
all_filenames = {}
for region_level, f_name in tile_filenames.viewitems():
    
    with open(f_name, 'r') as f:
  
        filenames = [basename(line.strip()) for line in f.readlines()] #filenames
        print filenames[:10], '...'
        all_filenames[region_level] = filenames
        tile_dicts[region_level] = {filename : i \
                                    for i, filename in enumerate(filenames)}

knn_trees = {}

for region_level, features in all_features.viewitems():
    ball_tree = NearestNeighbors(algorithm='ball_tree')

    print 'inserting into ' + str(region_level) + ' tree... (takes ~60 seconds)'

    m = time.time()
    neighbours = ball_tree.fit(features)
    knn_trees[region_level] = neighbours
    print 'inserted into tree, took: ' + str(time.time() - m) + 's'

# get index of 'search' in list 'strings'
def match_str(search, strings):
    for fni, fn in enumerate(filenames):
        if search in fn:
            return fni, fn
    return None, None

# bruteforce search
def find_matches(search, filenames, features):
    
    # given a tile name, find its index
    fni, fn = match_str(search, filenames)
    
    # tile not found
    if fn is None:
        return []
    
    #Pairwise distance
    distances = cdist([features[fni]], features, 'sqeuclidean')[0]
    
    matches = zip(distances, filenames)
    matches.sort()
    return matches

def maybe_wrap(x):
    if not hasattr(x, '__iter__'):
        return (x,)
    return x


app = Flask("terranet")

@app.route("/")
def search():
    b_start = time.time()
    
    searches = request.args.getlist('filename', None)
    level = int(request.args.get('level', 19))
    region = request.args.get('region', 'Allegheny')
    limit = int(request.args.get('limit', 25))
    if limit > 100:
        limit = 100

    for i, s in enumerate(searches):
        if not s.endswith('.png'):
            searches[i] = searches[i] + '.png'
    
    #tsne params
    perplexity = float(request.args.get('perplexity', 30.0))
    early_exaggeration = float(request.args.get('early_x', 4.0))
    learning_rate = float(request.args.get('learning_rate', 1000.0))
    metric = request.args.get('metric', 'euclidean')
    to_pca = bool(request.args.get('pca', True))
    pca_only = bool(request.args.get('pca_only', True))
    
    matches = []
    res = {}
    print searches
    
    region_level = (region, level)
    
    filenames = all_filenames[region_level]
    tile_dict = tile_dicts[region_level]
    features = all_features[region_level]
    neighbours = knn_trees[region_level]
    features_filename = features_filenames[region_level]
    if searches is not None:
        
        t_start = time.time()
        
        # makes searches into a singleton list if it isn't already a list
        searches = maybe_wrap(searches)
        
        search_features = []
        for search in searches:
            try:
                filename_index = tile_dict[search]
                search_feature = features[filename_index]
                search_features.append(search_feature)
            except KeyError:
                pass
        
        # centroid of search_features given
        
        if len(search_features) > 0:
            search_features = [np.mean(search_features, axis=0)]
            m = time.time()
            distances, indices = neighbours.kneighbors(search_features, limit)
            print 'Ball tree request time: ' + str(time.time() - m)

            similar_features = [features[i] for i in indices[0]]
                        
            if pca_only:
                reduced_dim = PCA(n_components=2).fit_transform(similar_features)
            else:
                reduced_dim = FastICA(n_components=2).fit_transform(similar_features)
            
            reduced_dim = reduced_dim/np.max(np.abs(reduced_dim))
            
            # key is 'tsne_pos' as server code still expects 'tsne_pos' as the key
            # even though dim. reduction is done with PCA now
            matches = [{'distance':dist, 'filename':filenames[i], 'tsne_pos':tuple(tsne_pos)} \
                       for dist, i, tsne_pos in zip(distances[0].tolist(), indices[0].tolist(), reduced_dim.tolist())]
            
            t_duration = time.time() - t_start
            print 'Total duration: ' + str(t_duration)
            res = {'duration' : t_duration,
                   'features_file': features_filename,
                   'matches': matches,
                   }
        else:
            res = {'error':'tile not found'}
    else:
        res = {'error':'filename param missing'}
    return json.dumps(res)

print 'Starting server.'
app.debug = True                                         
app.run(host='0.0.0.0', port=5000, use_reloader=False)
