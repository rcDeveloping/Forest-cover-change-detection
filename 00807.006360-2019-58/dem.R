# Read shp file
farm <- rgdal::readOGR('./output/fazPantanalWgs84.shp')

#   Import data - first a 30m DEM from NASA SRTM data
#  commands: raster::raster(), rgdal::readOGR() 
areaDEMutm <- raster::raster('./data/satellite/demSRTM30m.tif')
summary(areaDEMutm)

# Slope in degrees
slope <- raster::terrain(areaDEMutm, opt = 'slope', unit = 'degrees')
summary(slope)

# grassDir <- 'C:/Program Files/QGIS 3.16/app/grass/grass78'
# topo <- fasteraster::fasterTerrain(rast = areaDEMutm, 
#                                    slope = TRUE, slopeUnits = 'percent',
#                                    aspect = TRUE, grassDir = grassDir)

rasterVis::levelplot(slope,
                            margin = list(x = FALSE, y = TRUE),
                            col.regions = terrain.colors(16),
                            xlab = list(label = '', vjust = -0.25),
                            sub = list(
                                    label = 'Declividade (º)',
                                    font = 1,
                                    cex = 0.9,
                                    hjust = 1.5
                            ))

aspect <- raster::terrain(areaDEMutm, opt = 'aspect', unit = 'degrees')
plot(aspect)

# plot 
rasterVis::levelplot(areaDEMutm,
                     margin = list(x = FALSE, y = TRUE),
                     col.regions = terrain.colors(16),
                     xlab = list(label = '', vjust = -0.25),
                     sub = list(
                             label = 'Altitude (m)',
                             font = 1,
                             cex = 0.9,
                             hjust = 1.5
                     ))


