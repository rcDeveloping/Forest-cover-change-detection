# Forest-cover-change-detection
This data analysis study was carried out with spatial and remote sensing data to detect changes in the Amazonian rainforest through the R and JavaScript programming languages. 

## Satellite Data
The satellite data comes from the LANDSAT series of satellites, made available by the US Geological Survey ([USGS](https://www.usgs.gov/landsat-missions)) and accessed through the [Google Earth Engine](https://code.earthengine.google.com/) platform, using JavaScript programming language. The Google Earth Engine made it possible to filter the time series between 1985 and 2020 and calculate the NDVI vegetation index to detect changes in the evaluated forest cover. The filters used were: world reference system path and row, date, cloud cover, geometric root mean standard error model, and image quality, as shown in the code snippet below.
        
```js
var colFilter = ee.Filter.and(
        ee.Filter.eq('WRS_PATH', 223), 
        ee.Filter.eq('WRS_ROW', 66), 
        ee.Filter.date('1985-01-01','2020-12-31'), 
        ee.Filter.lt('CLOUD_COVER', 15), 
        ee.Filter.lt('GEOMETRIC_RMSE_MODEL', 10), 
        ee.Filter.or(ee.Filter.eq('IMAGE_QUALITY', 9), 
        ee.Filter.eq('IMAGE_QUALITY_OLI', 9))
 );
 ```
 
 ## Spatial Data
 The spatial data is formed by the following files:
 * .shp: contains the geometry data
 * .shx: is a positional index of the geometry data that allows to seek forwards and backwards the .shp file
 * .dbf: stores the attributes for each shape.
 * .prj: plain text file describing the projection

These data were previously processed in the geographic information system [QGIS](https://qgis.org/en/site/forusers/download.html) and load into R IDE [Studio](https://www.rstudio.com/) to produce thematic [maps](https://github.com/rcDeveloping/Forest-cover-change-detection/tree/main/00807.006360-2019-58) and spatial analysis.
