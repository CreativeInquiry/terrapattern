import numpy as np

numPts = 1000;
numDims = 100;
numK = 1000;

means = 200*np.random.rand(numK, numDims) - 100;
x=[];
for k in range(numK):
	x.append( means[k] +  np.random.randn(numPts,numDims) );
x = np.vstack(x);
print 'Data generated'
np.random.shuffle(x);
print 'Data shuffled'

filePath = 'data/train_'+str(numDims)+'d_'+str(numK)+'k_'+str(numPts)+'.dat';
filePt = open(filePath, 'w');
#filePt.write('%d %d\n' % (numPts*numK, numDims));
tmp = np.array(numPts*numK, dtype='int32');
tmp.tofile(filePt);
tmp = np.array(numDims, dtype='int32');
tmp.tofile(filePt);
x.tofile(filePt) #, x, delimiter=' ', newline='\n');
filePt.close();
print x[0,0]
print x[0,1]
print x[1,0]

numPts = 10

x = [];
for k in range(1,numK):
	x.append( means[k] + np.random.randn(numPts,numDims) );
x=np.vstack(x);

filePath = 'data/test_'+str(numDims)+'d_'+str(numK)+'k_'+str(numPts)+'.dat';
filePt = open(filePath, 'w');
#filePt.write('%d %d\n' % (numPts*numK, numDims));
tmp = np.array(numPts*numK, dtype='int32');
tmp.tofile(filePt);
tmp = np.array(numDims, dtype='int32');
tmp.tofile(filePt);
x.tofile(filePt) #, x, delimiter=' ', newline='\n');
filePt.close();

