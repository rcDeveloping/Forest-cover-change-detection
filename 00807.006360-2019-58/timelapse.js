/*
************************************************************************************
                       Timelapse de Série Temporal Landsat
                               Fazenda Pantanal
************************************************************************************
*/

// Carregar o polígono da Fazenda São Roberto II.
var faz = ee.FeatureCollection('users/nsrditec/fazPantanalWgs84');

// Retângulo para o GIF
var rec = ee.Geometry.Rectangle({
        coords: [[-50.0015491699999188, -9.1073266699999724],
         [-49.8004124999999860, -8.9138197199999727]], 
         geodesic: false
});

// Parâmetros de visualização da TI.
var pol = ee.Image().byte();
var visArea = pol.paint({
        featureCollection: faz, 
        color: 1, 
        width: 2
});

// Função para recortar as imagens em função do polígono da TI.
function clipImg(img) {
        return img.clipToCollection(faz);
}

// Função para reamostragem através do interpolador de convolução cúbica.
function resampleImg(img) {
        return img.resample('bicubic');
}

// Carregar as coleções do Landsat
// 5TM (Jan 1, 1984 - May 5, 2012).
var TM = ee.ImageCollection('LANDSAT/LT05/C01/T1_SR')
        // Classifica em ordem crescente a coleção pela data
        .sort('system_time:start', true)
        // Seleciona as bandas de interesse
        .select(['B5','B4','B3'], ['SWIR1', 'NIR', 'Red']);


// 8OLI (Apr 11, 2013 - 2020).
var OLI = ee.ImageCollection('LANDSAT/LC08/C01/T1_SR')
        // Classifica em ordem crescente a coleção pela data
        .sort('system_time:start', true)
        // Seleciona as bandas de interesse
        .select(['B6','B5','B4'],['SWIR1', 'NIR', 'Red']);

// Flitro para o período da coleção.
var colFilter = ee.Filter.and(
        // Seleciona a órbita/ponto 224/66
        ee.Filter.eq('WRS_PATH', 223), 
        ee.Filter.eq('WRS_ROW', 66),
        // Seleciona o perío do da série temporal
        ee.Filter.date('1985-01-01','2020-12-31'),
        // Seleciona cenas com cobertura máxima de nuvem abaixo de 15%
        ee.Filter.lt('CLOUD_COVER', 15),
        // Seleciona cenas com erro médio quadrático menor que 10m
        ee.Filter.lt('GEOMETRIC_RMSE_MODEL', 10),
        ee.Filter.or(
                // Seleciona cenas com a máxima qualidade para as coleções dos satélites Landsat
                ee.Filter.eq('IMAGE_QUALITY', 9),
                ee.Filter.eq('IMAGE_QUALITY_OLI', 9))
);

/*LANDSAT 7 ETM+ Collection
var l7 = ee.ImageCollection('LANDSAT/LE07/C01/T1_SR').select(['B3', 'B4', 'B5'],
          ['Red', 'NIR', 'SWIR1']);

var kernelSize = 10;
var kernel = ee.Kernel.square(kernelSize * 30, 'meters', false);

var gapFill = function(img) {
    var start = img.date().advance(-1, 'year');
    var end = img.date().advance(1, 'year');
    var fill = l7.filterDate(start, end).median();
    var regress = fill.addBands(img);
    regress = regress.select(regress.bandNames().sort());
    var fit = regress.reduceNeighborhood(
      ee.Reducer.linearFit().forEach(img.bandNames()), 
      kernel, null, false
    );
    var offset = fit.select('.*_offset');
    var scale = fit.select('.*_scale');
    var scaled = fill.multiply(scale).add(offset);
    return img.unmask(scaled, true);
};*/

var etmFilter = ee.ImageCollection('LANDSAT/LE07/C01/T1_SR')
    .filterBounds(faz)
    .filterDate('2020-03-23', '2020-03-25')
    .filter(ee.Filter.eq('WRS_PATH', 224))
    .filter(ee.Filter.eq('WRS_ROW', 66))
    .filter(ee.Filter.eq('IMAGE_QUALITY', 9))
    .filter(ee.Filter.lt('CLOUD_COVER', 20))
    .filter(ee.Filter.lt('GEOMETRIC_RMSE_MODEL', 10));
    var etmFirst = ee.Image(etmFilter.first());
    var checkStart = etmFirst.date().advance(-1, 'year');
    var checkEnd = etmFirst.date().advance(1, 'year');
    var etm = l7.filterDate(checkStart, checkEnd).median();

// Fusão das Coleções para gerar uma série temporal.
var serieTemp = ee.ImageCollection(TM.merge(OLI)).filter(colFilter).map(clipImg);

// Mostra os metadados da coleção. 
var n_IMG = serieTemp.getInfo();
print('Número de Cenas para o Período:', n_IMG);

// Calcula mediana nos pixels que intersectam a AOI para cada cena na coleção,
// e adiciona o nova valor nas  propriedades das cenas.
var medianCol = serieTemp.map(function(img) {
        var imgReduce = img.reduceRegion({
                reducer: ee.Reducer.median(), 
                geometry: rec, 
                scale: 30, 
                bestEffort: 
                true, 
                maxPixels: 1e9
        });
        return img.copyProperties(img, ['system:time_start', 'bandsNames']);
});

// Reduz a coleção através de um filtro de mediana intra anual.
var col = medianCol.map(function(img) {
        return img.set('year', img.date().get('year'));
});

// Faz uma Subcoleção a partir das cenas com anos distintos, evita
// cenas com mesma datas entre os sensores TM e ETM+.
var distinctYearCol = col.distinct('year');

// Filtro que identifica as imagens a partir da
// coleção completa e que corresponde ao 'ano' da coleção do ano distinto (distintoYearCol).
var filter = ee.Filter.equals({leftField: 'year', rightField: 'year'});

// Define um 'join'.
var join = ee.Join.saveAll('year_matches');

// Aplica o 'join' e converte o resultado da FeatureCollection para uma ImageCollection.
var joinCol = ee.ImageCollection(join.apply(distinctYearCol, col, filter));

// Aplica redução de mediana entre os anos da coleção.
var medianComp = joinCol.map(function(img) {
        var yearCol = ee.ImageCollection.fromImages(img.get('year_matches'));
        return yearCol.reduce(ee.Reducer.median()).set('system:time_start', 
        img.date().update());
});

// Mostra os metadados da coleção após redução por mediana intra anual. 
var medianInf = medianComp.getInfo();
print('Número de Cenas após filtro de Mediana:', medianInf);

// Parâmetros de Visualização para o vídeo.
var visST = medianComp.map(function(img) {
        var stat = img.select(
          ['SWIR1_median', 'NIR_median', 'Red_median']
        ).reduceRegion({
          geometry: rec, 
          reducer: ee.Reducer.percentile([5,90]), 
          scale: 30, 
          maxPixels: 1e9
        })
        return img.visualize({
                min: ee.List([stat.get('SWIR1_median_p5'),
                        stat.get('NIR_median_p5'),
                        stat.get('Red_median_p5')]), 
                        max: ee.List([stat.get('SWIR1_median_p90'), 
                        stat.get('NIR_median_p90'), 
                        stat.get('Red_median_p90')])
        });
});

// Obtem-se a posição do texto das datas.
var text = require('users/nsrditec/template:text');
var posTxt = text.getLocation(rec, 'right', '17%', '90%');

// Parâmetros de Visualização para animação do vídeo.
var visRgbTxt = visST.map(function(img) {
        var scale = 100;
        var textVis = 
        {
          fontSize: 10, 
          textColor: 'ffffff', 
          outlineColor: '000000', 
          outlineWidth: 3, 
          outlineOpacity: 0.6
        };
        var label = text.draw(ee.String(img.get('system:index')).slice(14,18), 
                posTxt, scale, visRgbTxt);
        return img.blend(label);
});

// Parâmetros de Visualização para o GIF.
var visGif = {
        crs: 'EPSG:3857',  // Pseudo Mercator
        dimensions: '640', // 640, 1080
        format: 'gif',
        region: rec,
        framesPerSecond: 3,
};

var parGif = ui.Thumbnail({
        image: visRgbTxt,
        params: visGif,
        style: {position: 'bottom-right'}
});

/* Exportar Video para o Google Drive.
Export.video.toDrive({
        collection: visRgbTxt,
        description: 'timelapse_1985_2020_faz_pantanal',
        folder: 'Video',
        framesPerSecond: 4,
        dimensions: '640x360', // 640x360 / 854 x 480 / 1280x720 / 1920x1080 / 
        region: faz,
        maxPixels: 1e9
});*/

// Mostrar o GIF e o Mosaico na tela.
Map.centerObject(faz, 12); // Centraliza o polígono na tela do mapa
Map.addLayer(visST); // Adiciona no mapa um mosaico com a última cena
//print(visRgbTxt.getVideoThumbURL(visGif)); // Mostra o link do GIF no console
Map.add(parGif); // Mostra o GIF no mapa
Map.addLayer(visArea); // Adiciona o polígo da Fazenda no mapa