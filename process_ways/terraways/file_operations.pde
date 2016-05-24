//=============================================
// Extract the list of valid JSON files.
void retrieveFilenames() {
  // Get list of filenames to process. 
  java.io.File dataFolder = new java.io.File(dataPath(""));
  String[] list = dataFolder.list();

  for (int f=0; f<list.length; f++) {
    java.io.File current_item = new java.io.File(dataPath("" + list[f]));
    if (current_item.isDirectory()) {

      java.io.File subFolder = new java.io.File(("" + current_item)); 
      String[] subFolderList = subFolder.list();
      if (subFolderList != null) {
        for (int g=0; g<subFolderList.length; g++) {
          java.io.File subfolderItem = new java.io.File(subFolderList[g]); 
          if ((subfolderItem.toString()).endsWith(".json")) {
            String aWaysFilename = dataPath("" + list[f] + "/" + subfolderItem);
            filenames.add(aWaysFilename);
          }
        }
      }
    } else {
      if ((current_item.toString()).endsWith(".json")) {
        String aWaysFilename = current_item.toString();
        filenames.add(aWaysFilename);
      }
    }
  }
}


//=============================================
boolean getLatLonBounds(JSONObject aWay) {
  // Extract the  polygon's lat/lon bounding box from the JSON files.
  minlon = maxlon = minlat = maxlat = 0;
  boolean bHasBounds = false; 
  try {
    JSONObject aBounds = aWay.getJSONObject("bounds");
    minlon = aBounds.getFloat("minlon");
    maxlon = aBounds.getFloat("maxlon");
    minlat = aBounds.getFloat("minlat");
    maxlat = aBounds.getFloat("maxlat");
    centerLat = (minlat + maxlat)/2.0; 
    centerLon = (minlon + maxlon)/2.0;
    bHasBounds = true;
  } 
  catch (Exception e) {
  }
  return bHasBounds;
}

//=============================================
boolean getLatLonGeometry(JSONObject aWay) {
  // Extract the map geometry from the JSON files.
  latLonPoints.clear(); 
  boolean bHasGeometry = false; 
  try {
    JSONArray aGeometry = aWay.getJSONArray("geometry");
    int nGeometry = aGeometry.size(); 
    bHasGeometry = (nGeometry > 0);
    for (int j=0; j<nGeometry; j++) {
      JSONObject aLatLon = aGeometry.getJSONObject(j);
      float lon = aLatLon.getFloat("lon"); 
      float lat = aLatLon.getFloat("lat"); 
      latLonPoints.add(new PVector(lat, lon));
    }
  } 
  catch (Exception e) {
  }
  return bHasGeometry;
}

//=============================================
boolean getCenter(JSONObject aWay) {
  boolean bHasCenter = false; 
  centerLat = 0;
  centerLon = 0;

  try {
    JSONObject aCenter = aWay.getJSONObject("center");
    centerLon = aCenter.getFloat("lon"); 
    centerLat = aCenter.getFloat("lat"); 
    bHasCenter = true;
  } 
  catch (Exception e) {
  }
  return bHasCenter;
}

//=============================================
boolean getRandomInteriorPoints(JSONObject aWay) {
  // If we have already made them, extract the randomized interior points from the JSON files.
  randomLatLonPointsInBoundary.clear(); 
  boolean bHasRandomizedInteriorPoints = false; 
  try {
    JSONArray aRandomPointsArray = aWay.getJSONArray("randomInteriorPoints");
    int nRandomInteriorPoints = aRandomPointsArray.size(); 
    bHasRandomizedInteriorPoints = (nRandomInteriorPoints > 0);
    for (int j=0; j<nRandomInteriorPoints; j++) {
      JSONObject aLatLon = aRandomPointsArray.getJSONObject(j);
      float lon = aLatLon.getFloat("lon"); 
      float lat = aLatLon.getFloat("lat"); 
      randomLatLonPointsInBoundary.add(new PVector(lat, lon));
    }
  } 
  catch (Exception e) {
  }
  return bHasRandomizedInteriorPoints;
}


//=============================================

/*
 JSONObject aWay = myWays.getJSONObject(0); 
 JSONArray outputJSONArray = new JSONArray();
 
 JSONArray aPointArray = new JSONArray(); 
 for (int i=0; i<N_RANDOM_POINTS; i++) {
 JSONObject aPointObject;
 aPointObject = new JSONObject(); 
 aPointObject.setFloat("lon", random(0,1));
 aPointObject.setFloat("lat", random(0,1));
 aPointArray.setJSONObject(i, aPointObject);
 }
 
 aWay.setJSONArray("randomInteriorPoints", aPointArray); 
 outputJSONArray.setJSONObject(0, aWay);
 saveJSONArray(outputJSONArray, "data/new.json");
 */
