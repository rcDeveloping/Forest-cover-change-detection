/*******************************************************************************************
                                     FUNCTIONS                                            
********************************************************************************************
*/

// Define coefficients supplied by Roy et al. (2016) for translating ETM+
// Modified from Google Develop Team https://code.earthengine.google.com/798ae7a268f8e2c8022433b9562785c0

// surface reflectance to OLI surface reflectance.
var coefficients = {
        itcps: ee.Image.constant([0.0003, 0.0088, 0.0061, 0.0412, 0.0254, 0.0172]).multiply(10000),
        slopes: ee.Image.constant([0.8474, 0.8483, 0.9047, 0.8462, 0.8937, 0.9071])
};

// Define function to get and rename bands of interest from OLI.
function renameOLI(img) {
        return img.select(
                ['B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'pixel_qa'],
		['Blue', 'Green', 'Red', 'NIR', 'SWIR1', 'SWIR2', 'pixel_qa']);
}

// Define function to get and rename bands of interest from ETM+.
function renameETM(img) {
        return img.select(
		['B1', 'B2', 'B3', 'B4', 'B5', 'B7', 'pixel_qa'],
		['Blue', 'Green', 'Red', 'NIR', 'SWIR1', 'SWIR2', 'pixel_qa']);
}

// Define function to apply harmonization transformation.
function etm2oli(img) {
        return img.select(['Blue', 'Green', 'Red', 'NIR', 'SWIR1', 'SWIR2'])
        .multiply(coefficients.slopes)
        .add(coefficients.itcps)
        .round()
        .toShort()
        .addBands(img.select('pixel_qa'));
}

// Define function to mask out clouds and cloud shadows.
function fmask(img) {
        var cloudShadowBitMask = 1 << 3;
        var cloudsBitMask = 1 << 5;
        var qa = img.select('pixel_qa');
        var mask = qa.bitwiseAnd(cloudShadowBitMask).eq(0).and(qa.bitwiseAnd(cloudsBitMask).eq(0));
        return img.updateMask(mask);
}

// Define Mask to remove tape of ETM+
function cloudMaskL7(img) {
        var qa = img.select('pixel_qa');
        var cloud = qa.bitwiseAnd(1 << 5).and(qa.bitwiseAnd(1 << 7)).or(qa.bitwiseAnd(1 << 3));
        var mask2 = img.mask().reduce(ee.Reducer.min());
        return img.updateMask(cloud.not()).updateMask(mask2);
}

// Define NDVI
var NDVI = function(img) {
        return img.normalizedDifference(['NIR','Red']).rename('NDVI');
};

// Define function to prepare OLI images.
function prepOLI(img) {
        var orig = img;
        img = renameOLI(img);
        img = fmask(img);
        img = NDVI(img);
        return ee.Image(img.copyProperties(orig, orig.propertyNames()));
}

// Define function to prepare ETM+ images.
function prepETM(img) {
        var orig = img;
        img = renameETM(img);
        img = cloudMaskL7(img);
        img = etm2oli(img);
        img = NDVI(img);
        return ee.Image(img.copyProperties(orig, orig.propertyNames()));
}

/*******************************************************************************************
                                        APPLICATION                         
********************************************************************************************
*/
// Define a point on the north slope of TEI 567027 Pantanal FARM, OR
// to extract time series for.
//var TEI = ee.FeatureCollection('users/nsrditec/TEI_567027');
var TEI = ee.FeatureCollection('users/nsrditec/TEI_567028');

// Display AOI on the map.
Map.centerObject(TEI, 10);
Map.addLayer(TEI, {color: 'f8766d'}, 'TEI');
Map.setOptions('HYBRID');

// Get Landsat surface reflectance collections for OLI, ETM+ and TM sensors.
var oliCol = ee.ImageCollection('LANDSAT/LC08/C01/T1_SR');
var etmCol= ee.ImageCollection('LANDSAT/LE07/C01/T1_SR');
var tmCol= ee.ImageCollection('LANDSAT/LT05/C01/T1_SR');

// Define a collection filter.
var colFilter = ee.Filter.and(
        ee.Filter.eq('WRS_PATH', 223), 
        ee.Filter.eq('WRS_ROW', 66), 
        ee.Filter.date('1985-01-01','2020-12-31'), 
        ee.Filter.lt('CLOUD_COVER', 15), 
        ee.Filter.lt('GEOMETRIC_RMSE_MODEL', 10), 
        ee.Filter.or(ee.Filter.eq('IMAGE_QUALITY', 9), 
        ee.Filter.eq('IMAGE_QUALITY_OLI', 9))
);

// Filter collections and prepare them for merging.
oliCol = oliCol.filter(colFilter).map(prepOLI);
etmCol = etmCol.filter(colFilter).map(prepETM);
tmCol = tmCol.filter(colFilter).map(prepETM);

// Merge the collections.
var col = oliCol.merge(etmCol).merge(tmCol);

// Reduce the ImageCollection to intra-annual median.
// Need to identify same-year images by a join.
// Start by adding a 'year' property to each image.
var col = col.map(function(img) {
        return img.set('year', img.date().get('year'));
});

// Apply median reduction among the collections.
var medianComp = col.select('NDVI').map(function(img) {
        var med = img.reduceRegion({
                geometry: TEI,
                reducer: ee.Reducer.median(),
                scale: 30
        });
        return img.set('NDVI', med.get('NDVI'));
});

// Get median collection information 
var infCol = col.sort('system:time_start', false);
print('SÉRIE TEMPORAL:', infCol);

// Export to drive
Export.table.toDrive({
        collection: medianComp, 
        description: 'TEI_567028_1985_2020_median_ndvi', 
        folder: 'img', 
        fileFormat: 'CSV'
});

// Buffer 5 km
var geom = TEI.geometry();
var buffer = geom.buffer(5000);
