

source(here::here("code/R/functions/get_emerged_area.R"))

library(raster)

#################################################

# Reclassify and save NDWI rasters


# list files (in this case raster TIFFs)
all_raster_files <- list.files(here::here("data/processed/raster/time_series"),
                               pattern = "*.tif*$",
                               recursive = FALSE, full.names = FALSE
)


# Set rules and create a reclassification matrix (2x3)
my_rules <- c(-1, 0.05, 0, 0.05, 1, 1)
reclmat <- matrix(my_rules, ncol = 3, byrow = TRUE)

# Since the zonal histogram algorithm requires a path to a raster file
# we need to save to a local folder the results of the reclassification
batch_reclass_and_save(
  raslist = all_raster_files,
  raster_path = "data/processed/raster/time_series/",
  rclmat = reclmat,
  outpath = "data/processed/raster/time_series/reclassified/"
)