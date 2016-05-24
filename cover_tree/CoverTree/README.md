# Cover Trees

We present a distributed and parallel extension and implementation of Cover Tree data structure for nearest neighbour search. The data structure was originally presented in and improved in:

1. Alina Beygelzimer, Sham Kakade, and John Langford. "Cover trees for nearest neighbor." Proceedings of the 23rd international conference on Machine learning. ACM, 2006.
2. Mike Izbicki and Christian Shelton. "Faster cover trees." Proceedings of the 32nd International Conference on Machine Learning (ICML-15). 2015.

## Organisation
1. All codes are under `src` within respective folder
2. Dependencies are provided under `lib` folder
3. For running cover tree an example script is provided under `scripts`
4. `data` is a placeholder folder where to put the data
5. `build` and `dist` folder will be created to hold the executables


## Requirements
1. gcc >= 4.8.4 or Intel&reg; C++ Compiler 2016 for using C++11 features

## How to use
We will show how to run our Cover Tree on a single machine using synthetic dataset

1. First of all compile by hitting make

   ```bash
     make
   ```

2. Generate synthetic dataset

   ```bash
     python data/generateData.py
   ```


3. Run Cover Tree

   ```bash
      dist/cover_tree data/train_100d_1000k_1000.dat data/test_100d_1000k_10.dat
   ```

The make file has some useful features:

- if you have Intel&reg; C++ Compiler, then you can instead

   ```bash
     make intel
   ```

- or if you want to use Intel&reg; C++ Compiler's cross-file optimization (ipo), then hit
   
   ```bash
     make inteltogether
   ```

- Also you can selectively compile individual modules by specifying

   ```bash
     make <module-name>
   ```

- or clean individually by

   ```bash
     make clean-<module-name>
   ```

## Performance
Based on our evaluation the implementation is easily scalable and efficient. For example on Amazon EC2 c4.8xlarge, we could insert more than 1 million vectors of 1000 dimensions in Euclidean space with L2 norm under 250 seconds. During query time we can process > 300 queries per second per core.

