# R version: 4.3.1
# rgee version: 1.1.6
# python version: 3.10.8
# numpy_version:  1.23.5
# earthengine_api version: 0.1.350

# Description -------------------------------------------------------------

# The aim of the script is to produce an ImageCollection of NDWI Satellite
# images, with one image mosaic per year or one image mosaic per month.
# The script will also export the resulting ImageCollection to Google Drive.
# Each image will be named in a machine readable format with the study area, the type of image and the date.
# This script uses the {rgee} package (Aybar et al., (2020) https://doi.org/10.21105/joss.02272)
# please see the instruction to install and use rgee: https://github.com/r-spatial/rgee

# In the "Initial Configuration" and "Variable Definition" section, the user will find all the options to edit,
# in this way the other sections can be run without any further edits.
# If more in depth changes are needed, be sure to look at the other sections as well.
# The "Initial Configuration" section is designed to be used with comments ("#")
# Comment variables or uncomment them depending on the things you want to obtain.
# Note that all the variables are mandatory (except crs, which if not specified will default to EPSG: 4326).

# List of editable variables
# More info on each of them are found at the specified line.
# - Lines 70-73, satellite: satellite to choose for the analysis. 
# - Lines 77-78, composite: the image composite to create, NDWI or true_color
# - Lines 82-83, pansharpen: TRUE/FALSE. Pansharpen the images or not
# - Line 86, img_crs: crs for the exported images
# - Line 102, start: start date for the analysis
# - Line 103, end: for how many months we need to gather images
# - Line 106, drive: TRUE/FALSE. Whether or not to export the images to Google Drive.
# - Line 122, cloud_filter_value: do not select images with a higher cloudy percentage than this
# - Line 115, gdrive_folder: the name of the folder in Google Drive
# - Lines 119-120, limit + limit_num: TRUE/FALSE. Limit the collection or not? (only for testing purposes)
# - Line 126, display: TRUE/FALSE. Display the images in an interactive map?
# - Lines 130-134, area: name of the area to append to the file name

# IMPORTANT: Change also the email inside ee_intialize() accordingly.
# IMPORTANT: You must have a registered account in Google Earth Engine and be authenticated through the earthengine-api
# See the rgee documentation at: https://r-spatial.github.io/rgee/articles/rgee01.html
# and the earthengine-api documentation at: https://developers.google.com/earth-engine/guides/python_install

# The script include a check about whether the selected date is actually present in the coverage for the selected satellite
# to avoid blank images or empty collections.
# All the images are exported following a naming convention: "area_image_type_YYYY-MM_satellite"
# Once the export task is completed, it will take some minutes for the images to show up in Google Drive
# Make sure to have some space on Google Drive or the process might not complete

# The function for generating list of dates and the one for acquiring one
# image per year is adapted from
# https://gis.stackexchange.com/questions/269313/mapping-over-list-of-dates-in-google-earth-engine

# Initial Configuration ---------------------------------------------------

library(rgee)
library(reticulate)

# # Initialize rgee
ee_Initialize(email = "titoloandrea@gmail.com", drive = TRUE, gcs = FALSE)

# Other optional checks
# ee_check()
# ee_check_credentials()
# ee_user_info()

# Variable Definition -----------------------------------------------------

# Choose which satellite we want to use
# IMPORTANT: Select only one at a time.
satellite <- "L5"
# satellite <- "L7"
# satellite <- "L8"
# satellite <- "S2"

# Define the image you want to generate
# Single-band NDWI  # or 3-band RGB
composite <- "NDWI"
# composite <- "RGB"

# Do we need to pansharpen the images? Default = FALSE.
# IMPORTANT: This only works for Landsat 8 images
# pansharpen <- TRUE
pansharpen <- FALSE

# Select exporting CRS for satellite images
img_crs = "EPSG: 32638"

# Select a starting date for the analysis
# Operational years:
  # - L5: 1984-2012
  # - L7: 1999-2022
  # - L8: 2013-present
  # - S2 (Surface reflectance): 2017-present

# The start variable set the starting point and the end variable determine how much
# the function needs to advance from the start variable.
# the sequence starts from 0 (the month defined in "start") and advance for eleven units, in our case months.
# You can potentially cover more than one year by defining e.g.: 
# - ee$List$sequence(0, 23) two years
# - ee$List$sequence(0, 35) three years and so on

start  <- ee$Date$fromYMD(1993, 01, 01)
end <- ee$List$sequence(0, 11)

# Choose weather or not to export to Google Drive.
drive <- TRUE
# drive <- FALSE


# Set the desired cloud filter value
# Careful, very low cloud filter values obviously lead to fewer images
cloud_filter_value <- 10

# Choose the name of the folder to store the images exported when drive = TRUE
gdrive_folder <- "rgeeMDASEmerginSites"

# Do you want to limit the collection to a certain amount of images?
# Might be useful for testing purpose
limit <- FALSE
limit_num <- 5

# Display the imageCollection in an interactive map?
# This might be slower depending on the number of images

# display <- TRUE
display <- FALSE

# Set the string for the area name to be used for file naming, depending on the composite

if (composite == "NDWI") {
   area <- ee$String("MDAS_NDWI_")
} else if (composite == "RGB") {
   area <- ee$String("MDAS_RBGA_")
}

# Other variables (optional) -----------------------------------------------------------------------

# Generate geometry according to the chosen area

geometry_mosul <- ee$Geometry$Polygon(
  coords = list(
    c(42.37340669234754, 37.07573420709028),
    c(42.37340669234754, 36.55681953712725),
    c(43.00237397750379, 36.55681953712725),
    c(43.00237397750379, 37.07573420709028)
  )
)

study_region <- geometry_mosul

# Variable definition according to the chosen satellite
# For each choice we define the ImageCollection, the bands to use to generate the NDWI,
# a string identifying the satellite (useful in the image naming later)
# and the pixel scale (spatial resolution)
# note that sentinel-2 composites use the SWIR band, which has 20m spat.resolution, which will also be the output resolution

if (satellite == "L5") {

    BaseColl <- ee$ImageCollection("LANDSAT/LT05/C01/T1_SR")

    green  <- "B2"
    swir <- "B5"
    rgb_bands <- c("B3", "B2", "B1")

    sensor <- ee$String("_L5")

    px_scale <- 30

} else if (satellite == "L7") {

    BaseColl <- ee$ImageCollection("LANDSAT/LE07/C01/T1_SR")

    green  <- "B2"
    swir <- "B5"
    rgb_bands <- c("B3", "B2", "B1")

    sensor <- ee$String("_L7")

    px_scale <- 30

} else if (satellite == "L8") {

    BaseColl <- ee$ImageCollection("LANDSAT/LC08/C01/T1_SR")

    green  <- "B3"
    swir <- "B6"
    rgb_bands <- c("B4", "B3", "B2")

    sensor <- ee$String("_L8")

    px_scale <- 30

    if (pansharpen == TRUE) {

      BaseColl <- ee$ImageCollection("LANDSAT/LC08/C01/T1_TOA")
      sensor  <- ee$String("_L8_PAN")
      px_scale <- 15

    }

} else if (satellite == "S2") {

    BaseColl <- ee$ImageCollection("COPERNICUS/S2_SR")

    green  <- "B3"
    swir <- "B11"
    rgb_bands <- c("B4", "B3", "B2")

    sensor <- ee$String("_S2")

    px_scale <- 20

    if (composite == "RGB") {
       px_scale <- 10
    }

}

# Functions Definition -----------------------------------------------------

# Function to generate a list of dates over which we will map the image collection function
# Use ee_utils_pyfunc when mapping over a ee_List object
# See https://r-spatial.github.io/rgee/articles/considerations.html#the-map-message-error

startDates <- end$map(ee_utils_pyfunc(
  function(x) start$advance(x, "month")
))

# For each satellite define the appropriate cloud masking function
# and the band-based cloud filter

if(satellite == "L5" || satellite == "L7") {

    cloudfunction <- function(image) {
        qa <- image$select('pixel_qa')
        # If the cloud bit (5) is set and the cloud confidence (7) is high
        # or the cloud shadow bit is set (3), then it's a bad pixel.
        cloudShadowBitMask <- bitwShiftL(1, 3)
        cloudBitMask <- bitwShiftL(1, 5)
        cloudConfidence <- bitwShiftL(1, 7)
        cloud <- qa$bitwiseAnd(cloudBitMask)$And(qa$bitwiseAnd(cloudConfidence))$Or(qa$bitwiseAnd(cloudShadowBitMask))
        # Remove edge pixels that don't occur in all bands
        mask2 <- image$mask()$reduce(ee$Reducer$min())
        return(image$updateMask(cloud$Not())$updateMask(mask2))
    }

    cloud_filter <- ee$Filter$lt("CLOUD_COVER", cloud_filter_value)

} else if (satellite == "L8") {

    cloudfunction <- function(image) {
        # Bits 3 and 5 are cloud shadow and cloud, respectively.
        cloudShadowBitMask <- bitwShiftL(1, 3)
        cloudsBitMask <- bitwShiftL(1, 5)
        # Get the pixel QA band.
        qa <- image$select('pixel_qa')
        # Both flags should be set to zero, indicating clear conditions.
        mask <- qa$bitwiseAnd(cloudShadowBitMask)$eq(0)$And(qa$bitwiseAnd(cloudsBitMask)$eq(0))
        return(image$updateMask(mask))
    }

    if(pansharpen == TRUE){

      # HSV-based Pan-Sharpening of Landsat 8 TOA images.
      panSharpenL8 <- function(image) {
        # Convert the RGB bands to the HSV color space.
        hsv <- image$select(rgb_bands)$rgbToHsv()

        # Swap in the panchromatic band and convert back to RGB.
        sharpened <- ee$Image$cat(hsv$select('hue'), hsv$select('saturation'), image$select('B8'))$hsvToRgb()
        return(image$addBands(sharpened))
      }

      # Cloud masking function for landsat images 
      cloudfunction <- function(image) {
        qa <- image$select('BQA')
        cloudBitMask <-  ee$Number(2)$pow(4)$int()
        mask <- qa$bitwiseAnd(cloudBitMask)$eq(0)
        return(image$updateMask(mask)$select("B.*")$copyProperties(image, list("system:time_start")))
      }
    }


    cloud_filter <- ee$Filter$lt("CLOUD_COVER", cloud_filter_value)

} else if (satellite == "S2") {

    # Function to mask clouds from the QA band in Sentinel images BOA
    cloudfunction <- function(image) {
        qa <- image$select("QA60")
        # Bits 10 and 11 are clouds and cirrus, respectively.
        cloudBitMask <- bitwShiftL(1, 10)
        cirrusBitMask <- bitwShiftL(1, 11)

        # Both flags should be set to zero, indicating clear conditions.
        mask <- qa$bitwiseAnd(cloudBitMask)$eq(0)$And(
        qa$bitwiseAnd(cirrusBitMask)$eq(0)
        )

        # Return the masked and scaled data, without the QA bands.
        image$updateMask(mask)$
        divide(10000)$
        select("B.*")$
        copyProperties(image, list("system:time_start"))
    }

    cloud_filter <- ee$Filter$lt("CLOUDY_PIXEL_PERCENTAGE", cloud_filter_value)

}


# Function to get image NDWI
getNDWI = function(img){
  greenBand <- img$select(green);
  swirBand <- img$select(swir);
  NDWI <- greenBand$subtract(swirBand)$divide(greenBand$add(swirBand))$rename("NDWI")
  return(NDWI)
}

# Function to generate NDWI mosaics for each month, depending on the composite chosen at the beginning
# also dependant on wether or not we need to pansharpen the images.
# Steps:
# Get a starting date from the object that we are going to pass to the function
# Get an end range for each step advancing by: 1 month from the start date
# Creates a date range, according to the start and end layer
# Create a name property for each image from the variables we set before and the selected year and month
# From the imageCollection defined in the variables:
  # filter the collection for images within our date ranges
  # Filter the collection for images within our study region
  # Filter for the percentage of cloud cover set before
  # Map the cloud function chosen before
  # Map the NDWI function created before, this will return the NDWI band of each image in the collection
  # If the chosen composite is RGB, skip the ndwi function and instead select the rgb bands
  # If we need to pansharpen the images, do it before selecting the rgb bands
  # Clip the images to our study region
# Apply the median reducer to mosaic the images of each year and set the variable name as a property of the images.
# For each composite, define also the visualization parameters to be used in case display==TRUE

if (composite == "NDWI") {

  yearmap <- function(m){
    start <- ee$Date(m)
    end <- ee$Date(m)$advance(1,"month")
    date_range <- ee$DateRange(start,end)
    name <- area$cat(start$format("YYYY-MM"))$cat(sensor)
    ImgYear <- BaseColl$
      filterDate(date_range)$
      filterBounds(study_region)$
      filter(cloud_filter)$ # Pre-filter to get less cloudy granules.
      map(cloudfunction)$
      map(getNDWI)$
      map(function(img){return(img$clip(study_region))})
    return(ImgYear$median()$set("name",name))
  }

  vizParams  <- list(min = -1, max = 1, palette = c('#a52a2a', '#ffffff', '#0000ff'))

} else if (composite == "RGB") {

  yearmap <- function(m){
    start <- ee$Date(m)
    end <- ee$Date(m)$advance(1,"month")
    date_range <- ee$DateRange(start,end)
    name <- area$cat(start$format("YYYY-MM"))$cat(sensor)
    ImgYear <- BaseColl$
      filterDate(date_range)$
      filterBounds(study_region)$
      filter(cloud_filter)$ # Pre-filter to get less cloudy granules.
      map(cloudfunction)$
      select(rgb_bands)$
      map(function(img){return(img$clip(study_region))})
    return(ImgYear$median()$set("name",name))
  }

  vizParams <- list(min = 0.0, max = 0.4, gamma = 1.2)

} else if (composite == "RGB" && pansharpen == TRUE && satellite == "L8") {
 
  yearmap <- function(m){
    start <- ee$Date(m)
    end <- ee$Date(m)$advance(1,"month")
    date_range <- ee$DateRange(start,end)
    name <- area$cat(start$format("YYYY-MM"))$cat(sensor)
    ImgYear <- BaseColl$
      filterDate(date_range)$
      filterBounds(study_region)$
      filter(cloud_filter)$ # Pre-filter to get less cloudy granules.
      map(cloudfunction)$
      map(panSharpenL8)$
      select(rgb_bands)$
      map(function(img){return(img$clip(study_region))})
    return(ImgYear$median()$set("name",name))
  }

  vizParams <- list(min = 0.0, max = 0.4, gamma = 1.2)

}

# Function to check wether chosen start year is between the coverage of the chosen satellite
# Operational years are gathered from https://developers.google.com/earth-engine/datasets/
# start_dates is a list of dates defined in the "startDates" variable.
# Create a list of sequential days covering the operation years of each satellite
# Isolate the list element corresponding to the satellite variable defined at the beginning
# Convert the start date from an EEObject to an R Date object
# Check if the selected date is present inside the list of dates
# If the chosen date is present in the list, the yearmap function defined above will be applied to the passed object

 check_valid_date <- function(start_dates) {

  l_coverage <- list("L5" = seq.Date(as.Date("1988-01-01"), as.Date("2012-01-01"), by = "day"),
    "L7" = seq.Date(as.Date("1999-01-01"), as.Date("2022-01-01"), by = "day"),
    "L8" = seq.Date(as.Date("2013-01-01"), as.Date(format(Sys.Date(), "%Y-%m-%d")), by = "day"),
    "S2" = seq.Date(as.Date("2017-03-28"), as.Date(format(Sys.Date(), "%Y-%m-%d")), by = "day")
  )

  l_index <- which(satellite == names(l_coverage))

  chosen_date <- as.Date(eedate_to_rdate(start))

  date_valid <- chosen_date %in% l_coverage[[l_index]]

  if (date_valid == TRUE) {

     cat("Selected start date match satellite coverage, applying the function... \n")

     start_dates$map(ee_utils_pyfunc(yearmap))

  } else if (date_valid == FALSE) {

    print(data.frame("Satellite" = c("L5", "L7", "L8", "S2"), "Coverage" = c("1988-2012", "1999-2022", "2013-present", "2017-present")))

    answer <- askYesNo("Selected start date do not match chosen satellite coverage, double check the table above for operational years.\n \n Do you want to proceed?")

    if (answer == TRUE) {
       start_dates$map(ee_utils_pyfunc(yearmap))
    } else {
       stop("\nSelected start date did not match chosen satellite coverage. Aborting...")
    }
  }
}

# Processing --------------------------------------------------------------

# Map the function over the list of dates created above
list_of_images <- check_valid_date(startDates)

# Transform the list of images to an ImageCollection for the batch export
ImgColl <- ee$ImageCollection(list_of_images)

# If needed, get information on the first image
# ee_print(ImgColl$first())


# Visualisation -----------------------------------------------------------


if (display) {

  img_name <- ImgColl$aggregate_array('name')$getInfo()

  Map$centerObject(study_region, zoom = 10)
  Map$addLayers(eeObject = ImgColl, visParams = vizParams, name = img_name, shown = FALSE)

}

# Export ------------------------------------------------------------------

# OPTIONAL: limit the Collection size and print info on its size
if (limit) {
  
  ExpColl <- ImgColl$limit(limit_num)
  cat("Limited Collection Size: ", ExpColl$size()$getInfo())
  
} else {
  
  ExpColl <- ImgColl
  cat("Collection Size: ", ExpColl$size()$getInfo())
  
}

# Export to Drive ---------------------------------------------------------

if (drive) {
  
# Count the number of images in the collection and convert them to a list
# the list will make possible to extract single images from the collection during the loop
  count <- ExpColl$size()$getInfo()
  ExpColl_list <- ExpColl$toList(count)
  
  # Loop to output each image
  for (index in seq_len(count)) {
    image <- ee$Image(ExpColl_list$get(index - 1))
    date <- ee_get_date_img(image)
    name <- ee$String(image$get('name'))$getInfo()
    print(name)
    task <- ee$batch$Export$image$toDrive(
      image,
      name,
      scale = px_scale,
      maxPixels = 1e9,
      folder = gdrive_folder,
      region = study_region,
      crs = img_crs
    )
    task$start()
    # ee_monitoring_test()
  }
  task$status()
}