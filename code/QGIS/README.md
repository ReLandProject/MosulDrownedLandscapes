# QGIS Models and Script Usage

This folder contains:
- A qgis model as .Model3 files
- The same models exported as Python Scripts

## Usage
*A description of the model with more information can be found in the model help text (on the right tab when launching the model not as batch)*. 
**Load the rasters into the project for the model to work as intended.**

### QGIS Models
In order to use the model:  
- Open QGIS and create a new project. Load the rasters to reclassify and the archaeological sites shapefile.
- At the top of the processing toolbox, click the "Models" icon -> either `Open Existing model` or `Add model to toolbox`.  
- **Use the `Reclassify and Get Zonal Histogram` model as batch process*- to generate shapefiles for more than one raster input (**RECOMMENDED**).
    - **IMPORTANT**: When using this model, in order to programmatically name the shapefile output, from the batch process interface, click the dropdown menu under "Polygons Zonal Histogram" and instead of "Automatic Fill" choose "Calculate with Expression". Once the expression window pops-up, insert the following expression:
    - Windows
    ```
    'C:/YOUR/PROJECT/DIRECTORY/output/shp/annual/' ||  substr(@inputsitespolygon, 7,3) || '_' || substr(@RastertoReclassify, 10, 4) || '.shp'
    ```
     - MacOS
    ```
    'Users/username/YOUR/PROJECT/DIRECTORY/output/shp/annual/' ||  substr(@inputsitespolygon, 7,3) || '_' || substr(@RastertoReclassify, 10, 4) || '.shp'
    ```

### Python Scripts
In order to run the python scripts:
- At the top of the processing toolbox, click the Python "Scripts" icon -> either `Open Existing Script` or `"Add Script to Toolbox"`. 
- Or Open the Python console (CTRL+ALT+P) and paste the script
