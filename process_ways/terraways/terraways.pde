/*
Golan Levin, 3/19/2016
 Program to add random interior points to OSM Way Polygons. 
 
 This program processes JSON files as follows: 
 terraways (This sketch folder)
 -- data 
 -- -- wayFolder
 -- -- -- wayFolder_ways.json
 
 It creates a file called
 data/wayFolder/wayFolder_ways_withpts.json
 Which contains 5 random points within each OSM Way polygon. 
 These can be found in a JSON array called randomInteriorPoints.
 */

boolean bProcessFilesAndExit = false; 

JSONArray myWays;
ArrayList<PVector> latLonPoints;   // Raw lat-lon points
ArrayList<PVector> xyPoints;       // points as they are displayed onscreen (tile-scaled)
ArrayList<PVector> randomLatLonPointsInBoundary; 
ArrayList<PVector> resampledlLatLonPoints; 
PVector handyVec;
PVector testPoint;
PVector testLatlon; 

ArrayList<String> filenames; 
String currentJsonFilename; 

int ZOOM_LEVEL = 19; 
int N_RANDOM_POINTS = 5; 
float TILE_SIZE = 256; 
boolean bDoDrawing = true; 
float centerLat = 0;
float centerLon = 0;
float minlon = 0;
float maxlon = 0; 
float minlat = 0; 
float maxlat = 0;


//================================================
void setup() {
  size(640, 640); 
  background(255); 

  filenames              = new ArrayList<String>(); 
  latLonPoints           = new ArrayList<PVector>(); 
  xyPoints               = new ArrayList<PVector>(); 
  resampledlLatLonPoints = new ArrayList<PVector>(); 
  randomLatLonPointsInBoundary = new ArrayList<PVector>(); 

  handyVec = new PVector();
  testPoint = new PVector();
  testLatlon = new PVector();

  retrieveFilenames(); 
  if (bProcessFilesAndExit) {
    processWayFiles();
    noLoop();
    exit();
  }

  //-----------------------------------------
  // Else, load a random file and display it. 
  int r = (int)random(filenames.size()); 
  currentJsonFilename = filenames.get(r); 
  try {
    JSONObject myjsonfile = loadJSONObject(currentJsonFilename) ;
    myWays = myjsonfile.getJSONArray("elements") ;
    myWays.remove(0) ; //removing the count object in each json file
    println ("Loaded: " + currentJsonFilename); 
    //myWays = loadJSONObject(currentJsonFilename); //FIX given change in format of json file
  } 
  catch (Exception e) {
    println ("Problem loading: " + currentJsonFilename + "\n" + e);
    exit();
  }
}


//================================================
void keyPressed() {
  // Export processed files if you hit spacebar. 
  if (!bProcessFilesAndExit) {
    if (key == ' ') {
      processWayFiles();
    }
  }
}

void processWayFiles() {
  int nFiles = filenames.size(); 
  String myOutputSuffix = "_withpts.json"; 
  int nWaysProcessed = 0; 
  int nInvalidWays = 0;

  // For every file in the directory
  for (int f=0; f<nFiles; f++) {
    String aFilePath = filenames.get(f); 
    currentJsonFilename = aFilePath; 

    // If this file is not the result of a previous run,
    if (!currentJsonFilename.endsWith(myOutputSuffix)) { 

      try {
        // Load the file
        JSONObject myjsonfile = loadJSONObject(currentJsonFilename) ;
        myWays = myjsonfile.getJSONArray("elements") ;
        myWays.remove(0) ; //removing the count object in each json file

        // How do I love thee? Let me count the ways. 
        int nWays = myWays.size();                 
        JSONArray myNewWays = new JSONArray();       

        // For each Way in the OSM object,
        int validWayCount = 0; 
        for (int i=0; i<nWays; i++) {

          // Fetch that Way, and make sure it's valid
          JSONObject aWay = myWays.getJSONObject(i); 
          boolean bHasLatLonBounds = getLatLonBounds(aWay);
          boolean bHasLatLonGeometry = getLatLonGeometry(aWay); 
          boolean bHasNoRandomInteriorPoints = !getRandomInteriorPoints(aWay); 
          if (bHasLatLonGeometry && bHasLatLonBounds && bHasNoRandomInteriorPoints) {

            boolean tooBig = doesPolygonExceedOneTile();
            println("tooBig = " + tooBig); 

            generateRandomLatLonPointsInBoundary();

            int nRandomLatLonPoints = randomLatLonPointsInBoundary.size(); 
            JSONArray aPointArray = new JSONArray(); 
            for (int p=0; p<nRandomLatLonPoints; p++) {
              JSONObject aPointObject;
              PVector aLatLonPoint = randomLatLonPointsInBoundary.get(p); 
              aPointObject = new JSONObject(); 
              aPointObject.setFloat("lat", aLatLonPoint.x);
              aPointObject.setFloat("lon", aLatLonPoint.y);
              aPointArray.setJSONObject(p, aPointObject);
            }

            aWay.setJSONArray("randomInteriorPoints", aPointArray); 
            myNewWays.setJSONObject(validWayCount, aWay);
            validWayCount++; 
            nWaysProcessed++;
          } else {
            nInvalidWays++;
          }
        }

        // Construct new filename
        int indexOfLastSlash = aFilePath.lastIndexOf('/'); 
        String theFoldername = aFilePath.substring(0, indexOfLastSlash+1); 
        String theFilename   = aFilePath.substring(indexOfLastSlash+1, aFilePath.length()); 
        int indexOfFileType  = theFilename.lastIndexOf(".json"); 
        String theFilenameRaw= theFilename.substring(0, indexOfFileType); 
        String newFilename   = theFilenameRaw + myOutputSuffix;
        String newFilepath   = theFoldername + newFilename;

        saveJSONArray(myNewWays, newFilepath);
        println ("Saved: " + newFilepath);
      } 
      catch (Exception e) {
        println ("Problem loading: " + currentJsonFilename + "\n" + e);
      }
    }
  }

  println ("Processed " + nWaysProcessed + " Ways");
  println ("Of which #invalid = " + nInvalidWays);
}


//================================================
void draw() {
  background(255); 

  int nWays = myWays.size(); 
  int whichOSMWay = max(0, min(mouseX, nWays-1));

  //for (int whichOSMWay = 0; whichOSMWay < nWays; whichOSMWay++) {
  {
    JSONObject aWay = myWays.getJSONObject(whichOSMWay); 
    boolean bHasLatLonBounds = getLatLonBounds(aWay);
    boolean bHasLatLonGeometry = getLatLonGeometry(aWay); 
    boolean bHasRandomInteriorPoints = getRandomInteriorPoints(aWay); 

    //-----------------------  
    if (bHasLatLonGeometry && bHasLatLonBounds) {
      if (!bHasRandomInteriorPoints) {

        boolean tooBig = doesPolygonExceedOneTile();
        println("tooBig = " + tooBig); 

        generateRandomLatLonPointsInBoundary();
      }
      if (bDoDrawing) {
        computeScreenPolygon(centerLat, centerLon);
        renderScreenPolygon(centerLat, centerLon);
      }
    }
  }

  if (bDoDrawing) {
    drawLevelBoxes();
  }
}



//=============================================
void generateRandomLatLonPointsInBoundary() {
  randomLatLonPointsInBoundary.clear();
  boolean bIsClosed = getPolygonIsClosed(); 

  if (bIsClosed) {
    int nTriesCount = 0; 
    int randomPointsCount = 0; 
    while ( (randomPointsCount < N_RANDOM_POINTS) && (nTriesCount < 10000)) {
      float latlonBoundsW = maxlat - minlat;
      float latlonBoundsH = maxlon - minlon; 
      float rlat = random(latlonBoundsW); 
      float rlon = random(latlonBoundsH); 
      testLatlon.set(minlat + rlat, minlon + rlon); 

      if (inPolyCheckArrayList (testLatlon, latLonPoints)) {
        randomLatLonPointsInBoundary.add(new PVector(testLatlon.x, testLatlon.y)); 
        randomPointsCount++;
      }
      nTriesCount++;
    }
  } else {
    // What to do if the Way boundary is not closed? 
    // Resample the boundary, and randomly select some points on this boundary.
    int nResamples = 500; 
    resampledlLatLonPoints.clear(); 
    resampleVector(latLonPoints, resampledlLatLonPoints, nResamples);

    int randomIndices[] = new int[N_RANDOM_POINTS];
    for (int i=0; i<N_RANDOM_POINTS; i++) {
      randomIndices[i] = 0;
    }

    for (int i=0; i<N_RANDOM_POINTS; i++) {
      // ensure there are no repeat values.
      int aRandomIndex = (int) random(nResamples); 
      boolean bRandomIndexAlreadyUsed = true; 
      while (bRandomIndexAlreadyUsed) {
        aRandomIndex = (int) random(nResamples); 
        bRandomIndexAlreadyUsed = false; 
        for (int j=0; j<i; j++) {
          if (aRandomIndex == randomIndices[j]) {
            bRandomIndexAlreadyUsed = true;
          }
        }
      }
      randomIndices[i] = aRandomIndex;
      PVector pVec = resampledlLatLonPoints.get(aRandomIndex); 
      randomLatLonPointsInBoundary.add(new PVector(pVec.x, pVec.y));
    }
  }
}

//=============================================
boolean getPolygonIsClosed() {
  boolean bClosed = true; 
  int nlatLonPoints = latLonPoints.size(); 
  if (nlatLonPoints > 1) {
    PVector p0 = latLonPoints.get(0); 
    PVector p1 = latLonPoints.get(nlatLonPoints-1); 
    float d = p0.dist(p1);
    if (d > 0.000001) {
      bClosed = false;
    }
  }
  return bClosed;
}



//=============================================
void computeScreenPolygon (float centerLat, float centerLon) {
  toPixelCoordinates(centerLat, centerLon);
  float centerX = handyVec.x;
  float centerY = handyVec.y;

  xyPoints.clear(); 
  int nLatLonPoints = latLonPoints.size(); 
  for (int j=0; j<nLatLonPoints; j++) {
    PVector aLatLonPoint = latLonPoints.get(j);
    float lat = aLatLonPoint.x;
    float lon = aLatLonPoint.y; 
    toPixelCoordinates(lat, lon);
    float x = handyVec.x - centerX;
    float y = handyVec.y - centerY;
    xyPoints.add(new PVector(x, y));
  }
}

//=============================================
boolean doesPolygonExceedOneTile() {

  toPixelCoordinates(minlat, minlon);
  float x0 = handyVec.x;
  float y0 = handyVec.y;

  toPixelCoordinates(maxlat, maxlon);
  float x1 = handyVec.x;
  float y1 = handyVec.y;

  float dx = abs(x1-x0); 
  float dy = abs(y1-y0); 
  if ((dx > TILE_SIZE) || (dy > TILE_SIZE)) {
    return true;
  }
  return false;
}



void renderScreenPolygon(float centerLat, float centerLon) {
  pushMatrix(); 
  translate(width/2, height/2); 
  toPixelCoordinates(centerLat, centerLon);
  float centerX = handyVec.x;
  float centerY = handyVec.y;

  // Draw the shape
  noFill(); 
  stroke(0, 0, 0, 100); 
  beginShape(); 
  for (int j=0; j<xyPoints.size (); j++) {
    PVector xyVec = (PVector) xyPoints.get(j); 
    vertex(xyVec.x, xyVec.y);
  }
  endShape();

  // draw the inside random points
  for (int i=0; i<randomLatLonPointsInBoundary.size (); i++) {
    PVector testLatlon = randomLatLonPointsInBoundary.get(i); 
    toPixelCoordinates(testLatlon.x, testLatlon.y);
    noStroke(); 
    fill(255, 0, 0); 
    ellipse(handyVec.x - centerX, handyVec.y - centerY, 5, 5);
  }

  popMatrix();
}


void renderScreenPolygonOLD (float centerLat, float centerLon) {
  pushMatrix(); 
  translate(width/2, height/2); 
  toPixelCoordinates(centerLat, centerLon);
  float centerX = handyVec.x;
  float centerY = handyVec.y;

  xyPoints.clear(); 
  int nLatLonPoints = latLonPoints.size(); 
  for (int j=0; j<nLatLonPoints; j++) {
    PVector aLatLonPoint = latLonPoints.get(j);
    float lat = aLatLonPoint.x;
    float lon = aLatLonPoint.y; 
    toPixelCoordinates(lat, lon);
    float x = handyVec.x;
    float y = handyVec.y;
    xyPoints.add(new PVector(x, y));
  }

  // Draw the shape
  noFill(); 
  stroke(0, 0, 0, 100); 
  beginShape(); 
  for (int j=0; j<xyPoints.size (); j++) {
    PVector xyVec = (PVector) xyPoints.get(j); 
    float x = xyVec.x - centerX;
    float y = xyVec.y - centerY;
    vertex(x, y);
  }
  endShape();

  // draw the inside random points
  for (int i=0; i<randomLatLonPointsInBoundary.size (); i++) {
    PVector testLatlon = randomLatLonPointsInBoundary.get(i); 
    toPixelCoordinates(testLatlon.x, testLatlon.y);
    noStroke(); 
    fill(255, 0, 0); 
    ellipse(handyVec.x - centerX, handyVec.y - centerY, 5, 5);
  }

  popMatrix();
}

//=============================================
void drawLevelBoxes() {
  pushMatrix(); 
  translate(width/2, height/2); 

  noFill(); 
  stroke (255, 0, 0); 
  rect(-TILE_SIZE/2, -TILE_SIZE/2, TILE_SIZE*1, TILE_SIZE*1); 
  rect(-TILE_SIZE*1, -TILE_SIZE*1, TILE_SIZE*2, TILE_SIZE*2); 
  rect(-TILE_SIZE*2, -TILE_SIZE*2, TILE_SIZE*4, TILE_SIZE*4); 
  noStroke();
  fill (255, 0, 0); 
  text ("19", -TILE_SIZE/2, -TILE_SIZE/2-4);
  text ("18", -TILE_SIZE*1, -TILE_SIZE*1-4);
  text ("17", -TILE_SIZE*2, -TILE_SIZE*2-4);

  popMatrix();
}

//=============================================
void toPixelCoordinates(double x, double y) { 
  // Convert (lat,lon) to pixel (x,y)
  double mapscale = 1<<ZOOM_LEVEL; 
  double siny = Math.sin(x * PI/180.0);
  siny = Math.min(Math.max(siny, -0.9999999), 0.9999999);
  x = TILE_SIZE * (0.5 + y / 360.0) ;
  y = TILE_SIZE * (0.5 - Math.log((1.0 + siny) / (1.0 - siny)) / (4.0 * PI));
  x *= mapscale; 
  y *= mapscale;
  handyVec.set((float)x, (float)y);
} 

//=============================================
boolean inPolyCheckArrayList(PVector v, ArrayList<PVector> p) {
  // Point-in-polygon test. 
  float a = 0;
  for (int i =0; i<p.size ()-1; ++i) {
    PVector v1 = p.get(i);
    PVector v2 = p.get(i+1);
    a += vAtan2cent180(v, v1, v2);
  }
  PVector v1 = p.get(p.size()-1);
  PVector v2 = p.get(0);
  a += vAtan2cent180(v, v1, v2);
  // if (a < 0.001) println(degrees(a));

  if (abs(abs(a) - TWO_PI) < 0.01) return true;
  else return false;
}

//---------------------------------------------------------
float vAtan2cent180(PVector cent, PVector v2, PVector v1) {
  // Helper function for point-in-polygon test. 
  PVector vA = v1.get();
  PVector vB = v2.get();
  vA.sub(cent);
  vB.sub(cent);
  vB.mult(-1);
  float ang = atan2(vB.x, vB.y) - atan2(vA.x, vA.y);
  if (ang < 0) ang = TWO_PI + ang;
  ang-=PI;
  return ang;
}


//=============================================
void resampleVector(ArrayList<PVector> path, ArrayList<PVector> resampledPath, int nResampledPoints) {
  int nPathPoints = path.size();
  double totalPathLength =  getPathLength(path);
  double RSL = totalPathLength / (double)nResampledPoints;
  double prevRemainder = RSL;
  int p = 0;
  if (nPathPoints <= 1) {
    for (p = 0; p < nResampledPoints; p++) {
      PVector lower = (PVector)path.get(0);
      double px = lower.x + (double)p * 0.0001;
      double py = lower.y + (double)p * 0.0001;
      PVector aPVec = new PVector((float)px, (float)py); 
      resampledPath.add(p, aPVec);
    }
  } else {
    for (int i = 0; i < nPathPoints - 1; i++) {
      PVector lower = path.get(i);
      PVector upper = path.get(i + 1);

      double Dx = upper.x - lower.x;
      double Dy = upper.y - lower.y;
      double segLength = Math.sqrt(Dx * Dx + Dy * Dy);
      double ASL = segLength;
      double dx = Dx / segLength;
      double dy = Dy / segLength;
      double RSLdx = dx * RSL;
      double RSLdy = dy * RSL;
      double neededSpace = RSL - prevRemainder;
      if (ASL >= neededSpace) {
        double remainder = ASL;
        double px = lower.x + neededSpace * dx;
        double py = lower.y + neededSpace * dy;
        if (p < nResampledPoints) {
          PVector aPVec = new PVector((float)px, (float)py); 
          resampledPath.add(aPVec);
          remainder -= neededSpace;
          p++;
        }
        int nPtsToDo = (int)(remainder / RSL);
        for (int d = 0; d < nPtsToDo; d++) {
          px += RSLdx;
          py += RSLdy;
          if (p < nResampledPoints) {
            PVector aPVec = new PVector((float)px, (float)py); 
            resampledPath.add(aPVec);
            remainder -= RSL;
            p++;
          }
        }
        prevRemainder = remainder;
      } else {
        prevRemainder += ASL;
      }
    }
  }
}

//=============================================
float getPathLength(ArrayList<PVector> path) {
  int nPathPoints = path.size();
  float perimeter = 0; 
  for (int p = 0; p < (nPathPoints-1); p++) {
    PVector p0 = (PVector)path.get(p);
    PVector p1 = (PVector)path.get(p+1);
    float d = p0.dist(p1); 
    perimeter += d;
  }
  return perimeter;
}

