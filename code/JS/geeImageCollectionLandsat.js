// ------------------------------
// Description
// ------------------------------

// The aim of the script is to produce an ImageCollection of NDWI Satellite
// images, with one image mosaic per year or one image mosaic per month.
// The script will also export the resulting ImageCollection to Google Drive.
// Each image will be named in a machine readable format with the study area, the type of image and the date.

// In the "Variable Definition" section, the user will find all the options to edit,
// in this way most of the other sections can be run without any further edits.
// If more in depth changes are needed, be sure to look at the other sections as well.
// The "Variable Definition" section is designed to be used with comments ("//")
// Comment variables or uncomment them depending on the things you want to obtain.
// Note that all the variables are mandatory (except crs, which if not specified will default to EPSG: 4326, and cloudfunction, which is only one in this script).

// At lines 51 to 63 there is a geometry expressed by a series of coordinates. You can leave as it is or import it in your GEE interface.
// At line 166, inside the yearmap function, comment out or uncomment lines 165 or 166 in order to switch between NDWI and RGB output (AFTER changing the other variables accordingly) 

// List of editable variables
// More info on each of them are found at the specified line.
// - Lines 71-74, baseColl: satellite to choose for the analysis. All are surface reflectance but use TOA for obtain pansharpen data.
// - Lines 83, start: start date for the analysis
// - Lines 84, end: for how many months we need to gather images
// - Line 84, cloud_filter_value: do not select images with a higher cloudy percentage than this
// - Line 87, greenBand: first band for NDWI image generation
// - Line 88, swirBand: second band for NDWI image generation
// - Line 91, rbgBands: define the red, green, and blue band according to the satellite
// - Line 96, area: String for the image names
// - Line 100, sensor: the name of the satellite to attach to the image name
// - Lines 103, exp_folder: the name of the folder in Google Drive where the images will be saved
// - Line 106-107, px_scale: spatial resolution of the output images once saved to Google Drive
// - Lines 110, crs: CRS of the images once exported to Google Drive
// - Lines 115-116, vizParams: visualisation parameters to be changed accordingly to the desired output. IT DOES NOT influence the saved images.
// - Lines 173, cloudfunction: choose the appropriate cloud masking function to be applied.

// All the images are exported following a naming convention: "area_image_type_YYYY-MM_satellite"
// Once the export task is completed, it will take some minutes for the images to show up in Google Drive
// Make sure to have some space on Google Drive or the process might not complete

// The function for generating list of dates and the one for acquiring one
// image per year is adapted from
// https://gis.stackexchange.com/questions/269313/mapping-over-list-of-dates-in-google-earth-engine


// ------------------------------
// Variable definition
// ------------------------------

// When pasting the code in GEE, hover with the mouse on "geometry_mosul" and then select "Convert" in the popup to convert the geometry to an import record.
var geometry_mosul = 
    /* color: #d63000 */
    /* shown: false */
    /* displayProperties: [
      {
        "type": "rectangle"
      }
    ] */
    ee.Geometry.Polygon(
        [[[42.37340669234754, 37.07573420709028],
          [42.37340669234754, 36.55681953712725],
          [43.00237397750379, 36.55681953712725],
          [43.00237397750379, 37.07573420709028]]], null, false)

// Study region
var study_region = geometry_mosul;

// -------- Variables for processing --------

// Select the collection to use
var baseColl = ee.ImageCollection('LANDSAT/LT05/C01/T1_SR'); // Landsat 5, available 1988-2012
//var baseColl = ee.ImageCollection('LANDSAT/LE07/C01/T1_SR'); // Landsat 7, available 1999-2022
//var baseColl = ee.ImageCollection('LANDSAT/LC08/C01/T1_SR'); // Landsat 8, available 2013-present
//var baseColl = ee.ImageCollection('LANDSAT/LC08/C01/T1_TOA'); // Landsat 8, available 2013-present


// The start variable set the starting point and the end variable determine how much
// the function needs to advance from the start variable.
// the sequence starts from 0 (the month defined in "start") and advance for eleven units, in our case months.
// You can potentially cover more than one year by defining e.g.: 
// - ee.List.sequence(0, 23) two years
// - ee.List.sequence(0, 35) three years and so on
var start = ee.Date.fromYMD(1993,1,1);
var end = ee.List.sequence(0, 11);

// Set the desired cloud filter value
// Careful, very low cloud filter values obviously lead to fewer images
var cloud_filter_value = ee.Filter.lt("CLOUD_COVER", 10); 

// Define bands to use in the NDWI function. Uncomment the appropriate one and comment out the other pair.

// Landsat 5 and Landsat 7
var greenBand = 'B2';
var swirBand = 'B5';

// Landsat 8
// var greenBand = 'B3';
// var swirBand = 'B6';

// Define RGB bands if we want to export rgb composites
var rbgBands = ['B3', 'B2', 'B1'] // Landsat 5-7
//var rbgBands = ['B4', 'B3', 'B2'] // landsat 8

// -------- Variables for export --------

// Set the string for the area name to be used for file naming
var area = ee.String('MDAS_NDWI_');
//var area == ee.String('MDAS_RGBA_')

// A string identifying the satellite (useful in the image naming later)
var sensor = ee.String("_L5");
// var sensor = ee.String("_L7");
// var sensor = ee.String("_L8");

// Choose the name of the folder to store the images exported
var exp_folder = 'geeMDASEmerginSites';

// Spatial resolution of the output images
var px_scale = 30;
//var px_scale = 15; // uncomment if doing pansharpening of Landsat 8 images

// Select exporting CRS for satellite images
var crs = 'EPSG: 32638'

// -------- Variables for visualization --------

// Define parameters for the visualisation in Google Earth Engine
var vizParams = { min: -1, max: 1, palette: ['brown', 'white', 'blue'] }; //NDWI
//var vizParams = { min: 0, max: 3000, gamma: 1.4, bands: rbgBands }; // Landsat SR RBG
//var vizParams = { min: 0, max: 0.3, gamma: 1.4, bands: rbgBands }; // Landsat TOA Pansharpened

// ------------------------------
// Functions and processing variables
// ------------------------------

// cloudmask function for landsat 5-7 Surface reflectance
var cloudMaskL457 = function(image) {
    var qa = image.select('pixel_qa');
    // If the cloud bit (5) is set and the cloud confidence (7) is high
    // or the cloud shadow bit is set (3), then it's a bad pixel.
    var cloud = qa.bitwiseAnd(1 << 5)
                    .and(qa.bitwiseAnd(1 << 7))
                    .or(qa.bitwiseAnd(1 << 3));
    // Remove edge pixels that don't occur in all bands
    var mask2 = image.mask().reduce(ee.Reducer.min());
    return image.updateMask(cloud.not()).updateMask(mask2);
};

// Cloud masking landsat 8 Surface reflectance
var maskL8sr = function (image) {
  // Bits 3 and 5 are cloud shadow and cloud, respectively.
  var cloudShadowBitMask = (1 << 3);
  var cloudsBitMask = (1 << 5);
  // Get the pixel QA band.
  var qa = image.select('pixel_qa');
  // Both flags should be set to zero, indicating clear conditions.
  var mask = qa.bitwiseAnd(cloudShadowBitMask).eq(0)
                 .and(qa.bitwiseAnd(cloudsBitMask).eq(0));
  return image.updateMask(mask);
}

// Cloud masking landsat Top-of-atmosphere
var maskLandsatclouds = function(image) {
  var qa = image.select('BQA');
  var cloudBitMask = ee.Number(2).pow(4).int();
  var mask = qa.bitwiseAnd(cloudBitMask).eq(0);
  return image.updateMask(mask)
      .select("B.*")
      .copyProperties(image, ["system:time_start"]);
};

// Select the appropriate cloudfunction from the above
var cloudfunction = cloudMaskL457;

// Function to get image NDWI
var getNDWI = function(img){
  var green = img.select(greenBand);
  var swir = img.select(swirBand);
  var NDWI = green.subtract(swir).divide(green.add(swir)).rename('NDWI');
  return NDWI;
};

// Function to pansharpen Landsat 8 images
var panSharpenL8 = function(image) {
  var rgb = image.select('B4', 'B3', 'B2');
  var pan = image.select('B8');
  // Convert to HSV, swap in the pan band, and convert back to RGB.
  var huesat = rgb.rgbToHsv().select('hue', 'saturation');
  var upres = ee.Image.cat(huesat, pan).hsvToRgb();
  return image.addBands(upres);
};

// Make start and end layers
var startDates = end.map(function(d) {
  return start.advance(d, 'month');
});
print("Month Start dates",startDates);

// Collect imagery by month
var yearmap = function(m){
  var start = ee.Date(m);
  var end = ee.Date(m).advance(1,'month');
  var date_range = ee.DateRange(start,end);
  var name = area.cat(start.format('YYYY-MM-dd')).cat(sensor);
  var ImgMonth = baseColl
    .filterDate(date_range)
    .filterBounds(study_region)
    .filter(cloud_filter_value)
    .map(cloudfunction)
    .map(getNDWI) // comment out this line when the line below is uncommented
    //.map(panSharpenL8) // uncomment this to get apply the pansharpening
    //.select(rbgBands)  // uncomment this to get rgb composites
    .map(function(img){return img.clip(study_region)});
  return(ImgMonth.median().set({name: name}));
};
print("yearmap",yearmap);

var monthlyImgList = startDates.map(yearmap);
print('monthly image list', monthlyImgList);
var imgMonthlyColl = ee.ImageCollection(monthlyImgList);
print("Monthly Collection", imgMonthlyColl);


/// ----- Images Visualisation -----

//Map.addLayer(ImgColl,ndwiParams,"NDWI"); // this add the last image of the collection (the more recent)
//select the number of images to display, set to 1 to display all of them (the value should not exceed the total generated images for each collection)

var images_to_not_display = 1; //this will remove n images from the collection and show all the others

var imageSetCollection = imgMonthlyColl.toList(imgMonthlyColl.size());

print(imageSetCollection);

var displayList= ee.List.sequence(0,ee.Number(imgMonthlyColl.size().subtract(images_to_not_display))).getInfo();
var fun = function(img){

  var image = ee.Image(imageSetCollection.get(img));
  var names = ee.String(image.get('name')).getInfo();
  var label = img + '_' +names;

  Map.addLayer(image,vizParams, label, false);
};

displayList.map(fun);
// Add study region to the map as well
Map.addLayer(mosul_lake, { color: "FF0000" }, "Mosul Lake", true, 0.6);
Map.centerObject(study_region, 10); // We center the map on our study area with a set zoom

// ------------------------------
// Export images to Google Drive
// ------------------------------

// Since there is no native way to export all the images in a Collection, we need to import an external module to do that
// The module was developed by Rodrigo E. Principe and is available at: https://github.com/fitoprincipe/geetools-code-editor
// This tool will create a folder in your Google Drive, where all the images in the collection will be exported.

var batch = require('users/fitoprincipe/geetools:batch'); // Here we load the module
batch.Download.ImageCollection.toDrive(imgMonthlyColl, exp_folder, {
  name: '{name}',
  scale: px_scale,
  region: study_region,
  type: 'float',
  crs: crs
});
