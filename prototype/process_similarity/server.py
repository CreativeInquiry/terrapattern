#!/usr/bin/env python

# This file loads the pre-computed code data from Process.ipynb and
# computes similarities between the vectors by using filenames.txt as keys.
# Finally, it uses Flask to provide this service as a web API.
# This code can run on any server that has enough RAM to store the npy file.
# The current npy file is about 2.2GB for 571k 1024 dimensional vectors.
# Computing similarity should generally take around 5-10 seconds, but
# it sometimes takes longer for unknown reasons.

from os.path import basename
from scipy.spatial.distance import cdist
from flask import Flask, request
import numpy as np
import json
import time

print 'Loading feature vectors.'
features_filename = 'level19/all_code_data.npy'
features = np.load(features_filename)

print 'Loading filenames.'
with open('filenames.txt', 'r') as f:
    filenames = [basename(line.strip()) for line in f.readlines()]

def match_str(search, strings):
    for fni, fn in enumerate(filenames):
        if search in fn:
            return fni, fn
    return None, None
        
def find_matches(search, filenames, features):
    fni, fn = match_str(search, filenames)
    if fn is None:
        return []
    distances = cdist([features[fni]], features, 'sqeuclidean')[0]
    matches = zip(distances, filenames)
    matches.sort()
    return matches

app = Flask('terranet')

@app.route('/')
def search():
    start = time.time()
    search = request.args.get('filename', None)
    limit = int(request.args.get('limit', 25))
    matches = []
    if search is not None:
        matches = find_matches(search, filenames, features)[:limit]
        matches = [{'distance': dist, 'filename': fn} for dist, fn in matches]
    duration = time.time() - start
    res = {
        'duration': duration,
        'features': features_filename,
        'matches': matches
    }
    return json.dumps(res)

print 'Starting server.'
app.debug = True
app.run(host='0.0.0.0') # must be 0.0.0.0 to accept external connections