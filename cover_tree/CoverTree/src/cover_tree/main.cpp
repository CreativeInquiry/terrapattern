//# define EIGEN_USE_MKL_ALL		//uncomment if available

# include <chrono>
# include <iostream>
# include <exception>
# include <Eigen/Core>

// User header
# include "cover_tree.h"
# include "parallel_cover_tree.h"

template<class InputIt, class UnaryFunction>
UnaryFunction parallel_for_each(InputIt first, InputIt last, UnaryFunction f)
{
	unsigned cores = std::thread::hardware_concurrency();

	auto task = [&f](InputIt start, InputIt end)->void{
		for (; start < end; ++start)
			f(*start);
	};

	const size_t total_length = std::distance(first, last);
	const size_t chunk_length = total_length / cores;
	InputIt chunk_start = first;
	std::vector<std::future<void>>  for_threads;
	for (unsigned i = 0; i < cores - 1; ++i)
	{
		const auto chunk_stop = std::next(chunk_start, chunk_length);
		for_threads.push_back(std::async(std::launch::async, task, chunk_start, chunk_stop));
		chunk_start = chunk_stop;
	}
	for_threads.push_back(std::async(std::launch::async, task, chunk_start, last));

	for (auto& thread : for_threads)
		thread.get();
	return f;
}

std::vector<point> readPointFile(std::string fileName)
{
	Eigen::initParallel();
	std::cout << "Number of OpenMP threads: " << Eigen::nbThreads( );
	for(int i=0; i<2048; ++i)
		powdict[i] = pow(base, i-1024);

	std::ifstream fin(fileName, std::ios::in|std::ios::binary);

	// Check for existance for file
	if (!fin)
		throw std::runtime_error("File not found : " + fileName);

	// Read the header for number of points, dimensions
	unsigned numPoints = 0;
	unsigned numDims = 0;
	fin.read((char *)&numPoints, sizeof(int));
	fin.read((char *)&numDims, sizeof(int));

	// Printing for debugging
	std::cout << "\nNumber of points: " << numPoints << "\nNumber of dims : " << numDims << std::endl;

	// List of points
	std::vector<point> pointList;
	pointList.reserve(numPoints);

	// Read the points, one by one
	double value;
	double *tmp_point = new double[numDims];
	for (unsigned ptIter = 0; ptIter < numPoints; ptIter++)
	{
		// new point to be read
		fin.read((char *)tmp_point, sizeof(double)*numDims);
		point newPt = point(numDims);

		for (unsigned dim = 0; dim < numDims; dim++)
		{
			newPt[dim] = tmp_point[dim];
		}

		// Add the point to the list
		pointList.push_back(newPt);
	}
	// Close the file
	fin.close();

	std::cout<<pointList[0][0] << " " << pointList[0][1] << " " << pointList[1][0] << std::endl;

	return pointList;
}

// Compute the nearest neighbor using brute force, O(n)
point bruteForceNeighbor(std::vector<point>& pointList, point queryPt)
{
	Eigen::IOFormat CommaInitFmt(Eigen::StreamPrecision, Eigen::DontAlignCols, ", ", ", ", "", "", "[", "]");

	point ridiculous = 1e200 * queryPt;
	point minPoint = ridiculous;
	double minDist = 1e300, curDist; // ridiculously high number
	

	for (const auto& p : pointList)
	{
		curDist = (queryPt-p).norm();
	    // Re-assign minimum
	    if (minDist > curDist)
		{
			minDist = curDist;
			minPoint = p;
		}
	}
	//std::cout << "Min Point: " << minPoint.format(CommaInitFmt) 
	//	      << " for query " << queryPt.format(CommaInitFmt) << std::endl;

	if (minPoint == ridiculous)
	{
		throw std::runtime_error("Something is wrong! Brute force neighbor failed!\n");
	}
	
	return minPoint;
}

void rangeBruteForce(std::vector<point>& pointList, point queryPt, double range, std::vector<point>& nnList)
{
    // Check for correctness
    for (const auto& node: nnList){
        if ( (node-queryPt).norm() > range){
            throw std::runtime_error( "Error in correctness - range!\n" );
        }
    }
    
    // Check for completeness
    int numPoints = 0;
    for (const auto& pt: pointList)
        if ((queryPt - pt).norm() < range)
            numPoints++;

    if (numPoints != nnList.size()){
	throw std::runtime_error( "Error in completeness - range!\n Brute force: " + std::to_string( numPoints ) + " Tree: " + std::to_string(  nnList.size() ) );
    }
}


void nearNeighborBruteForce(std::vector<point> pointList, point queryPt, int numNbrs, std::vector<point> nnList)
{

    double leastClose = (nnList.back() - queryPt).norm();

    // Check for correctness
    if (nnList.size() != numNbrs){
	std::cout << nnList.size() << " vs " << numNbrs << std::endl;
        throw std::runtime_error( "Error in correctness - knn (size)!" );
    }


    for (const auto& node: nnList){
        if ( (node - queryPt).norm() > leastClose + 1e-6){
	    std::cout << leastClose << " " << (node-queryPt).norm() << std::endl;
            for (const auto& n: nnList) 
                std::cout << (n-queryPt).norm() << std::endl;
            throw std::runtime_error( "Error in correctness - knn (dist)!" );
        }
    }
    
    // Check for completeness
    int numPoints = 0;
    std::vector<double> dists;
    for (const auto& pt: pointList){
        double dist = (queryPt - pt).norm();
        if (dist <= leastClose - 1e-6){
            numPoints++;
            dists.push_back(dist);
        }
    }

    if (numPoints != nnList.size()-1){
        std::cout << "Error in completeness - k-nn!\n";
        std::cout << "Brute force: " << numPoints << " Tree: " << nnList.size();
        std::cout << std::endl;
        for (auto dist : dists) std::cout << dist << " ";
        std::cout << std::endl;
    }
}


int main(int argv, char** argc)
{
    if (argv < 2)
        throw std::runtime_error("Usage:\n./main <path_to_train_points> <path_to_test_points>");

	std::cout << argc[1] << std::endl;
	std::cout << argc[2] << std::endl;

	Eigen::IOFormat CommaInitFmt(Eigen::StreamPrecision, Eigen::DontAlignCols, ", ", ", ", "", "", "[", "]");
	std::chrono::high_resolution_clock::time_point ts, tn;
    
	// Reading the file for points
	std::vector<point> pointList = readPointFile(argc[1]);

	CoverTree* cTree;
    // Parallel Cover tree construction
	ts = std::chrono::high_resolution_clock::now();
	ParallelMake pct(0, pointList.size(), pointList);
	pct.compute();
	cTree = pct.get_result();
	
	// Single core Cover tree construction
    	//cTree = new CoverTree(pointList);
	
	tn = std::chrono::high_resolution_clock::now();
	std::cout << "Build time: " << std::chrono::duration_cast<std::chrono::milliseconds>(tn - ts).count() << std::endl;
	//std::cout << *cTree << std::endl;
	cTree->calc_maxdist();
	//std::cout << *cTree << std::endl;

	// find the nearest neighbor
	std::vector<point> testPointList = readPointFile(argc[2]);
	ts = std::chrono::high_resolution_clock::now();
	
	//Serial search
	std::cout << "Querying serially" << std::endl;
	for (const auto& queryPt : testPointList)
	{
		point& ct_nn = cTree->NearestNeighbour(queryPt);
		//point bf_nn = bruteForceNeighbor(pointList, queryPt);
		//if (!ct_nn.isApprox(bf_nn))
		//{
		//	std::cout << "Something is wrong" << std::endl;
		//	std::cout << ct_nn.format(CommaInitFmt) << " " << bf_nn.format(CommaInitFmt) << " " << queryPt.format(CommaInitFmt) << std::endl;
		//	std::cout << (ct_nn - queryPt).norm() << " ";
		//	std::cout << (bf_nn - queryPt).norm() << std::endl;
		//}
        }
	
	// Parallel search (async)
	std::cout << "Quering parallely" << std::endl;
	parallel_for_each(testPointList.begin(), testPointList.end(), [&](point& queryPt)->void{
        	point& ct_nn = cTree->NearestNeighbourMulti(queryPt);	
		//point bf_nn = bruteForceNeighbor(pointList, queryPt);
		//if (!ct_nn.isApprox(bf_nn))
		//{
		//	std::cout << "Something is wrong" << std::endl;
		//	std::cout << ct_nn.format(CommaInitFmt) << " " << bf_nn.format(CommaInitFmt) << " " << queryPt.format(CommaInitFmt) << std::endl;
		//	std::cout << (ct_nn - queryPt).norm() << " ";
		//	std::cout << (bf_nn - queryPt).norm() << std::endl;
		//}
	});
	
	std::cout << "k-NN serially" << std::endl;
	std::vector<point> nnList = cTree->nearNeighbors(testPointList[0], 5);
        nearNeighborBruteForce(pointList, testPointList[0], 5, nnList);

	tn = std::chrono::high_resolution_clock::now();
	std::cout << "Query time: " << std::chrono::duration_cast<std::chrono::milliseconds>(tn - ts).count() << std::endl;
	system("pause");

    // Success
    return 0;
}
