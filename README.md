# Code for Drowned Landscapes: The Rediscovered Archaeological Heritage of the Mosul Dam Reservoir

Inside this repository there are:
- [Data](https://github.com/ReLandProject/MosulDrownedLandscapes/tree/main/data) used in the paper _**Drowned Landscapes: The Rediscovered Archaeological Heritage of the Mosul Dam Reservoir. Paola Sconzo, Francesca Simi, and Andrea Titolo, Bulletin of the American Society of Overseas Research 2023 389:, 165-189. DOI: https://doi.org/10.1086/724419.**_ 
  - **NOTE**: the present digital archive does not include original data used in the analysis (sites shapefile) as they are still under the process of publication. We are sorry for the inconvenience, but we will make sure to include a link to the dataset as soon as it will be available.
  - **Additional NOTE**: NDWI Raster data generated in Google Earth Engine/ R are not present in this repository because of their size, but they can be downloaded from [figshare](https://figshare.com/s/ab91db3522ad007ab22c) (c.800MB of data). Alternatively they can be generated using the GEE script or the R scripts in this repository.
  - When downloading the images from figshare, **make sure to place them in their respective folder**, i.e.: _**data/processed/raster/time-series**_ (inside the project folder). Otherwise the script for the zonal histogram will not work.
  - Reclassified NDWI composites generated through the 02_image_reclassification.R script (see below).
  - Mean water level data per chosen months generated from the [Database for Hydrological Time Series of Inland Waters (DAHITI)](https://dahiti.dgfi.tum.de/en/) as CSV.
  - Site types useful for qualitative analyses (no coordinates are present in these files) as CSV.
- [Code](https://github.com/ReLandProject/MosulDrownedLandscapes/tree/main/code) used to carry out the analyses. In detail:
  - **Google Earth Engine (GEE) Javascript code**, available in the relative [subfolder](https://github.com/ReLandProject/MosulDrownedLandscapes/tree/main/code/JS), used to generate monthly composites used in the analysis:  
    - A script for generating Landsat images.
    - A second script for generating Sentinel-2 images.
    - These two scripts are also available directly in Google Earth Engine
      - [Link for Landsat script](https://code.earthengine.google.com/c9d5037a078638df246b56857975b262?noload=true)
      - [Link for Sentinel script](https://code.earthengine.google.com/8117aa446748b197d616273d79d6e8bc?noload=true)
  - **R code** divided in five main scripts and one functions script, used to run the analysis, available in the [Script Subfolder](https://github.com/andreatitolo/IraqEmerginSites/tree/master/code/R).
    - The scripts are named in the order they are supposed to be run:
    - `01_rgee_image_collections.R` → an adaptation of the Google Earth Engine scripts in R, thanks to the [{rgee}](https://github.com/r-spatial/rgee) package.
    - `02_image_reclassification.R` → a small script to reclassify the NDWI images generated from the previous script.
    - `03_emerged_area_pct.R` → script that leverages the {qgisprocess} package and R to extract water and non-water pixels inside polygons representing sites extent (using the zonal histogram output from QGIS). It also gather all the outputs from the algorithm and merge them to create a single shapefile with readable percentages of emerged/submerged surface.
    - `04_quantitative_pct_info.R` → script that add some quantitative information to the output of the previous scripts, useful for wider interpretations.
    - `05_dataviz.R` → script to generate the figures present in the paper. 
    - a function folder with a `get_emerged_area.R` script. Here resides some functions that will be called from the other scripts (02, 03, 04).
  - **QGIS processing tools**, in the [QGIS Subfolder](https://github.com/ReLandProject/MosulDrownedLandscapes/tree/main/code/QGIS):
    - Standalone qgis model as .model3 file
      - This model covers the steps carried out in the 02 and half of the 03 scripts described above
    - Same models as python scripts
- **Accuracy assessment data** used for the error matrix mentioned in the paper (available on [figshare](https://figshare.com/s/43606b0a2cf48e8e0df4) because of data size).
- The present repository is also archived on zenodo at: [![DOI](https://zenodo.org/badge/660115267.svg)](https://zenodo.org/badge/latestdoi/660115267)

  
# License 

All the code is shared under the [CC-BY-SA 4.0 License](https://creativecommons.org/licenses/by-sa/4.0/).

[![License: CC BY-SA 4.0](https://img.shields.io/badge/License-CC_BY--SA_4.0-lightgrey.svg)](https://creativecommons.org/licenses/by-sa/4.0/)

# Reproduce the analysis

More detailed instructions on how to reproduce the analyses are available in the [Wiki](https://github.com/ReLandProject/MosulDrownedLandscapes/wiki).

