# ifndef COVER_TREE_H
# define COVER_TREE_H

//#define DEBUG

#include <vector>
#include <stack>
#include <Eigen/Core>

#include <exception>

#include <fstream>
#include <iostream>

typedef Eigen::VectorXd point;

// Base to use for the calculations
double base = 2.0;
double powdict[2048];

//template<class point>
class CoverTree
{
public:
	
	// structure for each node
	struct Node
	{
		point _p;						// point associated with the node
		std::vector<Node*> children;				// list of children
		int level;						// current level of the node
		double maxdistUB;					// Upper bound of distance to any of descendants
		double tempDist;
		
		double covdist()
		{
			return powdict[level + 1024]; //pow(base, level);
		}

		double sepdist()
		{
			return powdict[level + 1023]; // pow(base, level - 1);
		}

		void setChild(const point& pIns)
		{
			Node* temp = new Node;
			temp->_p = pIns;
			temp->level = level - 1;
			temp->maxdistUB = 0;
			//maxdistUB = std::max(maxdistUB, tempDist);
			children.push_back(temp);
		}

		void setChild(Node* pIns)
		{
			if( pIns->level != level - 1)
			{
				Node* current = pIns;
				std::stack<Node*> travel;
				current->level = level-1;
				travel.push(current);
				while (travel.size() > 0)
				{
					current = travel.top();
					travel.pop();

					for (const auto& child : *current)
					{
						child->level = current->level-1;
						travel.push(child);
					}

				}
			}
			children.push_back(pIns);
		}
		
		double dist(const point& pp) const
		{
			return (_p - pp).norm();
		}

		double dist(Node* n) const
		{
			return (_p - n->_p).norm();
		}

		/*** Iterator access ***/
		inline std::vector<Node*>::iterator begin()
		{
			return children.begin();
		}

		inline std::vector<Node*>::iterator end()
		{
			return children.end();
		}

		inline std::vector<Node*>::const_iterator begin() const
		{
			return children.begin();
		}

		inline std::vector<Node*>::const_iterator end() const
		{
			return children.end();
		}

		friend std::ostream& operator<<(std::ostream& os, const Node& ct)
		{
			Eigen::IOFormat CommaInitFmt(Eigen::StreamPrecision, Eigen::DontAlignCols, ", ", ", ", "", "", "[", "]");
			os << "(" << ct._p.format(CommaInitFmt) << ":" << ct.level << ":" << ct.maxdistUB << ")";
			return os;
		}
	};

protected:

	Node* root;			// Root of the tree
	int minScale;			// Minimum scale
	int maxScale;			// Minimum scale

	void insert(Node* current, const point& p)
	{
		#ifdef DEBUG
			if( current->dist(p) > current->covdist() )
				throw std::runtime_error("Internal insert got wrong input!");
		#endif
		
		bool flag = true;
		for (const auto& child : *current)
		{
			child->tempDist = child->dist(p);
			if ( child->tempDist <= child->covdist() )
			{
				insert(child, p);
				flag = false;
				break;
			}
		}

		if (flag)
		{
			current->setChild(p);
			if(minScale > current->level-1)
			{
				minScale = current->level-1;
				//std::cout<< minScale << " " << maxScale << std::endl;
			}
		}
	}

	void insert(Node* current, Node* p)
	{
		#ifdef DEBUG
			if( current->dist(p) > current->covdist() )
				throw std::runtime_error("Internal insert got wrong input!");
		#endif
		
		bool flag = true;
		for (const auto& child : *current)
		{
			child->tempDist = child->dist(p);
			if ( child->tempDist <= child->covdist() )
			{
				insert(child, p);
				flag = false;
				break;
			}
		}

		if (flag)
		{
			current->setChild(p);
			if(minScale > current->level-1)
			{
				minScale = current->level-1;
				//std::cout<< minScale << " " << maxScale << std::endl;
			}
		}
	}

	Node* NearestNeighbour(Node* current, const point &p, Node* nn) const
	{	
		if (current->tempDist < nn->tempDist)
			nn = current;

		for (const auto& child : *current)
			child->tempDist = child->dist(p);
		auto comp_x = [](Node* a, Node* b) { return a->tempDist < b->tempDist; };
		std::sort(current->begin(), current->end(), comp_x);

		for (const auto& child : *current)
		{
			if ( nn->tempDist > child->tempDist - child->maxdistUB )
				nn = NearestNeighbour(child, p, nn);
		}
		return nn;
	}
	
	Node* NearestNeighbourMulti(Node* current, const point &p, Node* nn) const
	{
		double tempDist = nn->dist(p);
		if (current->dist(p) < tempDist)
			nn = current;
	
		for (const auto& child : *current)
		{
			if (tempDist > child->dist(p) - child->maxdistUB)
				nn = NearestNeighbourMulti(child, p, nn);
		}
		return nn;
	}

	void nearNeighbors(Node* current, const point& p, std::vector<Node*>& nnList) const
	{	
        // If the current node is eligible to get into the list
        // TODO: An efficient implementation ?
		auto comp_x = [](Node* a, Node* b) { return a->tempDist < b->tempDist; };
        	
		double curDist = current->tempDist;
		double bestNow = nnList.back()->tempDist;
		
		if(curDist < bestNow)
		{
			nnList.insert( 
           			std::upper_bound( nnList.begin(), nnList.end(), current, comp_x ),
           			current 
        		);
			nnList.pop_back();
		}

		for (const auto& child : *current)
			child->tempDist = child->dist(p);
		std::sort(current->begin(), current->end(), comp_x);

		for (const auto& child : *current)
		{
			if ( nnList.back()->tempDist > child->tempDist - child->maxdistUB )
				nearNeighbors(child, p, nnList);
		}
	}
	
	void nearNeighborsMulti(Node* current, const point& p, std::vector<Node*>& nnList) const
	{	
        // If the current node is eligible to get into the list
        // TODO: An efficient implementation ?
                double curDist = current->dist(p);
		double bestNow = nnList.back()->dist(p);
		
		if(curDist < bestNow)
		{
			auto k = nnList.begin();
			for( ; curDist > (*k)->dist(p); ++k);
			nnList.insert(k, current);
			nnList.pop_back();
		}

		for (const auto& child : *current)
		{
			if ( bestNow > child->dist(p) - child->maxdistUB )
				nearNeighborsMulti(child, p, nnList);
		}
	}
	
	
	void rangeNeighbors(Node* current, const point &p, double range, std::vector<Node*>& nnList) const
	{	
        // If the current node is eligible to get into the list
		if (current->tempDist < range)
            nnList.push_back(current);

        // Sort the children
		for (const auto& child : *current)
			std::cout << child->_p.rows() << " ";
		std::cout << std::endl;
		for (const auto& child : *current)
			child->tempDist = child->dist(p);
		auto comp_x = [](Node* a, Node* b) { return a->tempDist < b->tempDist; };
		std::sort(current->begin(), current->end(), comp_x);

		for (const auto& child : *current){
			if (range > child->tempDist - child->maxdistUB)	
				rangeNeighbors(child, p, range, nnList);
		}
	}
	
	void rangeNeighborsMulti(Node* current, const point &p, double range, std::vector<Node*>& nnList) const
	{	
		// If the current node is eligible to get into the list
		if (current->dist(p) < range)
	        nnList.push_back(current);

		for (const auto& child : *current){
			if (range > child->dist(p) - child->maxdistUB)
				rangeNeighborsMulti(child, p, range, nnList);
		}
	}

	std::vector<Node*> mergeHelper(Node* p, Node* q)
	{
		#ifdef DEBUG
			assert(root->level == ct->root->level);
			assert(root->dist(ct->root) < root->covdist());
		#endif
		
		std::vector<Node*> sepcov, uncovered, leftovers;
		for (const auto& r : *q)
		{
			if (p->dist(r) < p->covdist())
			{
				bool flag = true;
				for (const auto& s : *p)
				{
					if (s->dist(r) <= s->covdist())
					{
						std::vector<Node*> leftoverss = mergeHelper(s, r);
						leftovers.insert(leftovers.end(), leftoverss.begin(), leftoverss.end());
						flag = false;
						break;
					}
				}

				if (flag)
				{
					sepcov.push_back(r);
				}
			}
			else
			{
				uncovered.push_back(r);
			}
		}

		//children ← children ∪ sepcov
		for (const auto& s : sepcov)
			p->children.push_back(s);

		insert(p, q->_p);
		delete q;

		for (const auto& r : leftovers)
		{
			if (p->dist(r) <= p->covdist())
				insert(p, r);
			else
				uncovered.push_back(r);
		}

		return uncovered;
	}

	static void clear(Node* current)
	{
		std::stack<Node*> travel;

		travel.push(current);
		while (travel.size() > 0)
		{
			current = travel.top();
			travel.pop();

			for (const auto& child : *current)
				travel.push(child);

			delete current;
		}
	}

public:
	
	// Inserting a point
	void insert(const point& p)
	{
		if ( root->dist(p) > root->covdist() )
		{
			while (root->dist(p) > 2 * root->covdist())
			{
				Node* current = root;
				Node* parent = NULL;
				while (current->children.size()>0)
				{
					parent = current;
					current = current->children.back();
				}
				if (parent != NULL)
				{
					parent->children.pop_back();
					current->level = root->level + 1;
					current->children.push_back(root);
					root = current;
				}
				else
				{
					root->level += 1;
				}
			}
			Node* temp = new Node;
			temp->_p = p;
			temp->level = root->level + 1;
			temp->children.push_back(root);
			root = temp;
			maxScale = root->level;
			//std::cout << "Upward: " <<  minScale << " " << maxScale << std::endl;
		}
		else
		{
			root->tempDist = root->dist(p);
			insert(root, p);
		}
		return;
	}

	// First the number of nearest neighbor
	point& NearestNeighbour(const point &p) const
	{
		root->tempDist = root->dist(p);
		return NearestNeighbour(root, p, root)->_p;
	}
	
	point& NearestNeighbourMulti(const point &p) const
	{
		return NearestNeighbourMulti(root, p, root)->_p;
	}
	
	// Function to obtain the numNbrs nearest neighbors
	std::vector<point> nearNeighbors(const point queryPt, int numNbrs) const
	{
		root->tempDist = root->dist(queryPt);

        // Do the worst initialization
        Node* dummyNode = new Node();
        dummyNode->tempDist = std::numeric_limits<double>::max();
        // List of k-nearest points till now
        std::vector<Node*> nnListn(numNbrs, dummyNode);
	nearNeighbors(root, queryPt, nnListn);
		
	std::vector<point> nnList;
	for( const auto& node : nnListn )
		nnList.push_back(std::move(node->_p));
	return nnList;
	}
	std::vector<point> nearNeighborsMulti(const point queryPt, int numNbrs) const
	{
        // Do the worst initialization
        Node* dummyNode = new Node();
	dummyNode->_p = 1e100*root->_p;
        dummyNode->tempDist = std::numeric_limits<double>::max();
        // List of k-nearest points till now
        std::vector<Node*> nnListn(numNbrs, dummyNode);
		nearNeighborsMulti(root, queryPt, nnListn);
		
		std::vector<point> nnList;
		for( const auto& node : nnListn )
			nnList.push_back(std::move(node->_p));
		return nnList;
	}

    // Function to get the neighbors around the range
	std::vector<point> rangeNeighbors(const point queryPt, double range) const
    {
        root->tempDist = root->dist(queryPt);
        // List of nearest neighbors in the range
        std::vector<Node*> nnListn;
		rangeNeighbors(root, queryPt, range, nnListn);

		std::vector<point> nnList;
		for( const auto& node : nnListn )
			nnList.push_back(std::move(node->_p));
        return nnList;
    }
	
	// Function to get the neighbors around the range
	std::vector<point> rangeNeighborsMulti(const point queryPt, double range) const
    {
        // List of nearest neighbors in the range
        std::vector<Node*> nnListn;;
		rangeNeighborsMulti(root, queryPt, range, nnListn);

		std::vector<point> nnList;
		for( const auto& node : nnListn )
			nnList.push_back(std::move(node->_p));
        return nnList;
    }

	void Merge(CoverTree* ct)
	{
		#ifdef DEBUG
			assert(root->level >= ct->root->level);
		#endif

		//Make sure d(p,q) < covdist(p)
		while (root->dist(ct->root) > root->covdist())
		{
			//std::cout << "Inside while 1" << std::endl;
			Node* current = root;
			Node* parent = NULL;
			while (current->children.size()>0)
			{
				parent = current;
				current = current->children.back();
			}
			if (parent != NULL)
			{
				parent->children.pop_back();
				current->level = root->level + 1;
				current->children.push_back(root);
				root = current;
			}
			else
			{
				root->level += 1;
			}
		}

		// Make sure level(p) == level(q)
		while (root->level > ct->root->level)
		{
			//std::cout << "Inside while 2" << std::endl;
			Node* current = ct->root;
			Node* parent = NULL;
			while (current->children.size()>0)
			{
				parent = current;
				current = current->children.back();
			}
			if (parent != NULL)
			{
				parent->children.pop_back();
				current->level = ct->root->level + 1;
				current->children.push_back(ct->root);
				ct->root = current;
			}
			else
			{
				ct->root->level += 1;
			}
		}

		std::vector<Node*> leftovers = mergeHelper(root, ct->root);
		for (const auto& p : leftovers)
			insert(root, p);

		return;
	}

	//contructor: needs atleast 1 point to make a valid covertree
	CoverTree(const point& p)
	{
		minScale=1000;
		maxScale=0;
		
		root = new Node;
		root->_p = p;
		root->level = 0;
		root->maxdistUB = 0;
	}

	//contructor: needs atleast 1 point to make a valid covertree
	CoverTree(std::vector<point>& pList)
	{
		point temp = pList.back();
		pList.pop_back();
		
		minScale=1000;
		maxScale=0;

		root = new Node;
		root->_p = temp;
		root->level = 0;
		root->maxdistUB = 0;

		int i = 0;
		for (const auto& p : pList)
			insert(p);

		pList.push_back(temp);
	}

	//contructor: needs atleast 1 point to make a valid covertree
	CoverTree(std::vector<point>& pList, int begin, int end)
	{
		point temp = pList[begin];

		minScale = 1000;
		maxScale = 0;

		root = new Node;
		root->_p = temp;
		root->level = 0;
		root->maxdistUB = 0;

		for (int i = begin + 1; i < end; ++i)
			insert(pList[i]);
	}

	//destructor: deallocating all memories by a post order traversal
	~CoverTree()
	{
		clear(root);
	}

	//get root level == max_level
	int get_level()
	{
		return root->level;
	}

	// Debug function
	friend std::ostream& operator<<(std::ostream& os, const CoverTree& ct)
	{
		Eigen::IOFormat CommaInitFmt(Eigen::StreamPrecision, Eigen::DontAlignCols, ", ", ", ", "", "", "[", "]");

		std::stack<Node*> travel;
		Node* curNode;

		// Initialize with root
		travel.push(ct.root);

		// Qualititively keep track of number of prints
		int numPrints = 0;
		// Pop, print and then push the children
		while (travel.size() > 0)
		{
			if (numPrints > 5000)
				throw std::runtime_error("Printing stopped prematurely, something wrong!");
			numPrints++;

			// Pop
			curNode = travel.top();
			travel.pop();

			// Print the current -> children pair
			// os << *curNode << std::endl;
			for (const auto& child : *curNode)
				os << *curNode << " -> " << *child << std::endl;

			// Now push the children
			for(int i = curNode->children.size()-1; i>=0; --i)
				travel.push(curNode->children[i]);
		}

		return os;
	}

	//find true maxdist
	void calc_maxdist()
	{	
		std::vector<Node*> travel;
		std::vector<Node*> active;
		
		Node* current = root;
	
		root->maxdistUB = 0;	
		travel.push_back(root);
		while( travel.size() > 0 )
		{
			current = travel.back();
		
			if(current->maxdistUB == 0){
			while(current->children.size()>0)
			{
				active.push_back(current);
				// push the children
				for(int i = current->children.size()-1; i>=0; --i)
				{
					current->children[i]->maxdistUB = 0;
					travel.push_back(current->children[i]);
				}
				current = current->children[0];
			}}
			else
				active.pop_back();
			
			// find distance with current node
			for (const auto& n : active)
				n->maxdistUB = std::max( n->maxdistUB, n->dist(current) );

			// Pop
			travel.pop_back();
		}
	}
};

#endif
