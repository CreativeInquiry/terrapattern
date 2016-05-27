--
--  Copyright (c) 2016, Facebook, Inc.
--  All rights reserved.
--
--  This source code is licensed under the BSD-style license found in the
--  LICENSE file in the root directory of this source tree. An additional grant
--  of patent rights can be found in the PATENTS file in the same directory.
--
--  extracts features from an image using a trained model
--

require 'torch'
require 'paths'
require 'os'
require 'cudnn'
require 'cunn'
require 'image'
local t = require './datasets/transforms'

-- Load the model

if not (#arg == 5) then
    print('Usage: th extract-features.lua <model> <list of filenames> <path to image folder> <output filename>')
    os.exit()
end

local model = torch.load(arg[1])

-- Remove the fully connected layer
assert(torch.type(model:get(#model.modules)) == 'nn.Linear')
model:remove(#model.modules)

-- Evaluate mode
model:cuda()
model:evaluate()

-- The model was trained with this input normalization
local meanstd = {
   mean = { 0.485, 0.456, 0.406 },
   std = { 0.229, 0.224, 0.225 },
}

local transform = t.Compose{
   t.Scale(256),
   t.ColorNormalize(meanstd),
   t.CenterCrop(224),
}


local file = io.open(arg[2], "r");
local nlines = assert(io.popen("cat "..arg[2].." | wc -l", "r"));
nlines = nlines:read('*all')
local features
local k = 0
print(nlines)
t = sys.clock()

local image_folder = arg[3]

for line in file:lines() do
   -- load the image as a RGB float tensor with values 0..1
   local img = image.load(image_folder..line, 3, 'float')

   -- Scale, normalize, and crop the image
   img = transform(img)

   -- View as mini-batch of size 1
   img = img:view(1, table.unpack(img:size():totable()))
   -- Get the output of the layer before the (removed) fully connected layer
   local output = model:forward(img:cuda()):squeeze(1)
   if not features then
      features = torch.FloatTensor(tonumber(nlines), output:size(1)):zero()
   end
   if k % 1000 == 0 then
        print('Done: '..k..' took: '..sys.clock()-t)
        t = sys.clock()
   end
   features[k + 1]:copy(output)
   k = k + 1
end

torch.save(arg[4], features)
print('saved features to '..arg[4])
