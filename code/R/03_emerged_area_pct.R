# Script to calculate the zonal histogram from annual and monthly rasters over a series of Polygon shapefiles

library(qgisprocess)
library(raster)
library(stringr)
library(dplyr)
library(janitor)
library(foreign)
library(magrittr)
library(here)
library(sf)
library(fuzzyjoin)

source(here::here("code/R/functions/get_emerged_area.R"))

# Filter and prepare data for analysis in QGIS ----------------------------

# Load the data

mdas_polys <- st_read(here::here("data/raw/shp", "MDAS-poligoni.shp"),
                      stringsAsFactors = FALSE
)

mdas_sites <- st_read(here::here("data/raw/shp", "MDAS_points.shp"),
                      stringsAsFactors = FALSE
)

# Attach certainty fields from points to the polys ------------------------

# Replace T. Rownak (exc) with T. Rownak_exc otherwise some join function do not detect it
mdas_sites$Name[grep("T. Rownak .*", mdas_sites$Name)] <- "T. Rownak_exc"
mdas_polys$Name[grep("T. Rownak .*", mdas_polys$Name)] <- "T. Rownak_exc"

# For the data to be "joined" correctly we need to first drop the geometry column on the point layer
# this will ensure that the distinct() function works correctly
# dplyr::inner_join expects a data frame as y variable (mdas_sites@data)
# Since more than one point can be included in one polygon, use fuzzy_inner_join
# from the {fuzzyjoin} package to match partial string
# distinct remove duplicate rows

mdas_polys_filtered <- mdas_polys %>%
  fuzzy_inner_join(., st_set_geometry(mdas_sites, NULL)[, 2:3], by = c("Name" = "Name"), match_fun = str_detect) %>%
  select(-Name.y) %>%
  rename(Name = Name.x) %>%
  distinct(.keep_all = TRUE) # remove duplicate rows (all elements of the row must be identical!)


# Keep the duplicate with the highest certainty (identified by the function below)
# Different numbers in the certainty column prevent distinct() to eliminate one of the rows
# Use the | operator to combine the results from the two functions
dupl <- mdas_polys_filtered[which(duplicated(mdas_polys_filtered$Name) | duplicated(mdas_polys_filtered$Name, fromLast = TRUE)), ]
dupl

# Retrieve the row index of the point with lowest certainty (higher number) and use it later to remove it
# programmatic way instead of index <- c(102, 247, 258)
index  <- as.numeric(
  rownames(
    dupl[with(dupl, ave(Certainty, Name, FUN = max) == Certainty), ]
    )
  )

index

# Transform the dataframe into an SF object again
mdas_polys_filtered <- mdas_polys_filtered[-index, ] %>%
  mutate(Name = str_replace(Name, "T. Rownak_exc", "T. Rownak (exc.)")) %>%  # Reformat to the original name
  st_as_sf()

# Turn all the column names to lowercase for easier referencing
colnames(mdas_polys_filtered) <- tolower(colnames(mdas_polys_filtered))

# Keep only the selected fields and remove the id column
mdas_polys_filtered <- subset(mdas_polys_filtered, select = -id)


## Load Rasters -----------------------------------------------------------------------
# List the reclassified rasters

r_raster_files <- list.files(
  here::here("data/processed/raster/time_series/reclassified"),
  pattern = "*.tif$",
  recursive = TRUE, full.names = FALSE
)

# Get details on the qgisprocess path
# qgis_configure()
# Use the function below if qgis_configure() was already run once on your system
qgis_configure(use_cached_data = TRUE)

# Get information on the desired algorithm
# note how the algorithm takes the PATH to a raster file as raster input 
qgis_show_help("native:zonalhistogram")


# Create an R function from the qgis function (see https://github.com/paleolimbot/qgisprocess/issues/15)
zonal_histogram <- qgis_function("native:zonalhistogram")

# Apply the function to generate new shapefiles with the zonal histogram algorithm

get_zonal_histo(
  polys = mdas_polys_filtered,
  raster_files = r_raster_files,
  raster_path = here::here("data/processed/raster/time_series/reclassified"),
  out_path = here::here("output/shp/zonal_histogram_output")
)


#  Load output data -----------------------------------------------------------------------

# Merge results from QGIS and compute percentage of emerged site area --------
poly_names_min <- list.files(here::here("output/shp/zonal_histogram_output"),
                             pattern = "*min.dbf",
                             ignore.case = FALSE
)

poly_names_max <- list.files(here::here("output/shp/zonal_histogram_output"),
                             pattern = "*max.dbf",
                             ignore.case = FALSE
)


# read.dbf is from the "foreign" package
polys_year_list_min <- lapply(poly_names_min, function(fn) {
  read.dbf(here::here("output/shp/zonal_histogram_output", fn), as.is = TRUE)
})


polys_year_list_max <- lapply(poly_names_max, function(fn) {
  read.dbf(here::here("output/shp/zonal_histogram_output", fn), as.is = TRUE)
})


# Data manipulation -----------------------------------------------------------------------

site_type_location <- read.csv(here::here("data/raw/csv/MosulDamSiteTypeandLocation.csv")) 
colnames(site_type_location) <-   tolower(colnames(site_type_location))

# Fix an erroneous record for the 1995_12_min layer
# Erroneous recording gives 1 pixel to water instead of registering all polygon as outside
# 1995 is the third year
# Extract row index (255)
site_index <- which(polys_year_list_min[[3]]$name=="MDReS-25")

# Replace the values (original were 34 and 1)
polys_year_list_min[[3]]$X1995.12_0[[site_index]] <- 35
polys_year_list_min[[3]]$X1995.12_1[[site_index]] <- 0

# Define fields that will not be subject to percentage conversion
# This will be all the fields except those added by the zonal histogram
fields_to_not_adorn <- c("fid", "name", "area_cert", "area", "certainty")

# Define numeric fields with site measurements
# This will avoid errors when transforming percentage fields in integer
# the mutate() function will not touch these fields
measurement_fields <- c("area")


## Min Water level -----------------------------------------------------------------------

# Apply the function to get a data frame with columns containing zonal percentages of all the loaded dbf
# This represent the percentage of site area emerged and submerged each year
# Apply the function on the datasets and replace the original sf object
# The function outputs a data frame, we need to join the geometry column to have an sf object.
mdas_polys <- get_zonal_pct(polys_year_list_min)  %>% st_set_geometry(., st_geometry(mdas_polys))

# a <- get_zonal_pct(polys_year_list_min)  %>% st_set_geometry(., st_geometry(mdas_polys))

mdas_polys <- mdas_polys %>% 
  full_join(., select(site_type_location, c("name", "site_typ", "topo_set")), by = "name") %>% 
  relocate(c("site_typ", "topo_set"), .after = "area") %>% 
  relocate("area_cert", .after = "certainty")

# Export the results
st_write(
  obj = mdas_polys,
  dsn = here::here("output/shp", "MDAS_polys_area_pct_min.shp"),
  layer = "MDAS_polys_area_pct_min",
  driver = "ESRI Shapefile", 
  append = FALSE # Overwrite existing layers
)

# Write csv for easier sharing
write.csv(mdas_polys@data, here::here("output/csv", "MDAS_polys_area_pct_min.csv"))


## Max Water level -----------------------------------------------------------------------

mdas_polys <- get_zonal_pct(polys_year_list_max) %>% st_set_geometry(., st_geometry(mdas_polys))

mdas_polys <- mdas_polys %>% 
  full_join(., select(site_type_location, c("name", "site_typ", "topo_set")), by = "name") %>% 
  relocate(c("site_typ", "topo_set"), .after = "area") %>% 
  relocate("area_cert", .after = "certainty")

# Export the results
st_write(
  obj = mdas_polys,
  dsn = here::here("output/shp", "MDAS_polys_area_pct_max.shp"),
  layer = "MDAS_polys_area_pct_max",
  driver = "ESRI Shapefile", 
  append = FALSE
)

write.csv(mdas_polys@data, here::here("output/csv", "MDAS_polys_area_pct_max.csv"))
