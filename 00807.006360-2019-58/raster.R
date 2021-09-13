library(raster)
library(ggplot2)
library(dplyr)

#https://datacarpentry.org/r-raster-vector-geospatial/09-vector-when-data-dont-line-up-crs/index.html
landsat1988 <- raster::stack('./data/satellite/LT05_223066_19880908.tif')
landsat1988 <- raster::projectRaster(landsat, crs = '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs')

landsat2010 <- raster::stack('./data/satellite/LT05_223066_20100905.tif')
landsat2010 <- raster::projectRaster(landsat, crs = '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs')


ggplot(band_5_Df) +
        geom_raster(aes(x, y, alpha = NIR), na.rm = TRUE) +
        #scale_alpha(range = c(0.15, 0.65)) +
        #coord_quickmap(expand = F) 
        coord_sf()

aoi1985 <- raster::crop(landsat1988, farm, fill = NA)
aoi2010 <- raster::crop(landsat2010, farm, fill = NA)

df.1988 <- as.data.frame(aoi1988, xy = TRUE) %>%
        mutate(date = '1988-09-08')

df.2010 <- as.data.frame(aoi2010, xy = TRUE) %>%
        mutate(date = '2010-09-05')

df <- rbind(df.1988, df.2010)


tmap::tm_shape(aoi1988) +
        tmap::tm_raster(palette = 'Greys') +
        tmap::tm_shape(farm) +
        tmap::tm_borders()


img1988 <- pairs(aoi1988[[3:4]], main = "Red versus NIR 1988")
img2010 <- pairs(aoi2010[[3:4]], main = "Red versus NIR 2010")

##PCA
set.seed(123)
sr1988 <- raster::sampleRandom(aoi1988, 700)
sr2010 <- raster::sampleRandom(aoi2010, 700)

par(mfrow = c(1, 2))
plot(sr1988[, c(3, 4)], main = 'Red versus NIR 1988')
plot(sr2010[, c(3, 4)], main = 'Red versus NIR 2010')

pca <- prcomp(sr, scale = TRUE)
head(pca)
screeplot(pca)
pci <- predict(aoi, pca, index = 1:4)
plot(pci[[1]])

pc1 <- reclassify(pci[[1]], c(-Inf,0,1,0,Inf,NA))
pc2 <- reclassify(pci[[2]], c(-Inf,0,1,0,Inf,NA))
par(mfrow = c(1, 2))
plotRGB(aoi, r = 6, g = 5, b = 3, axes = TRUE, stretch = "hist", main = "RGB-653")
plotRGB(aoi, r = 6, g = 5, b = 3, axes = TRUE, stretch = "hist", main = "RGB-653 and PC3")
plot(pc2, legend = FALSE, add = TRUE)


## plot RGB
plotRGB(landsat, 5, 4, 3, stretch = 'hist')


