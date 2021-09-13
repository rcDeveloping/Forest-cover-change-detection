## Load packages
library(dplyr)
library(stringr)
library(ggplot2)
library(plotly)
library(changepoint)
library(lubridate)
library(reshape2)
library(ggpmisc)
library(tidyr)

## Set work directory
setwd('D:/Robson/home_office/00807.006360-2019-58/')


###  Read the NDVI data frames - TEI 567027 ###
ndvi_TEI_567027 <- read.csv(
        './data/satellite/TEI_567027_1985_2020_median_ndvi.csv',
        header = TRUE,
        sep = ',',
        dec = '.'
)

###  Read the NDVI data frames - TEI 567028 ###
ndvi_TEI_567028 <- read.csv(
        './data/satellite/TEI_567028_1985_2020_median_ndvi.csv',
        header = TRUE,
        sep = ',',
        dec = '.'
)

## Cleaning the NDVI data frame - TEI 567027
ndvi_TEI_567027 <- ndvi_TEI_567027 %>%
        select(-c("PIXEL_QA_VERSION", "system.band_names", ".geo", "LANDSAT_ID",
                  "system.footprint", "system.bands", "ESPA_VERSION",
                  "SR_APP_VERSION", "system.time_start", "system.version",
                  "LEVEL1_PRODUCTION_DATE", "system.asset_size", "system.id",
                  "SENSING_TIME", "EARTH_SUN_DISTANCE",
                  "IMAGE_QUALITY_OLI", "IMAGE_QUALITY_TIRS", "CLOUD_COVER_LAND")) %>%
        mutate(Date = str_sub(system.index, start = 15)) %>%
        mutate(
                Date = ifelse(SATELLITE == 'LANDSAT_7' | SATELLITE == 'LANDSAT_8',
                              str_sub(Date, start = 3), Date)
        ) %>%
        select(-('system.index')) %>%
        mutate(Date = as.Date(Date, '%Y%m%d')) %>%
        # mutate(Classe = ifelse(
        #         Date <= "2000-12-31", "Floresta", "Antropiza??o")) %>%
        rename(index = NDVI) %>%
        mutate(index_type = 'NDVI TEI 567027-C') %>%
        filter(!is.na(index)) %>%
        filter(index >= 0)

## Summary of NDVI data frame in the TEI area
summary(ndvi_TEI_567027)


## Cleaning the NDVI data frame - TEI 567028
ndvi_TEI_567028 <- ndvi_TEI_567028 %>%
        select(-c("PIXEL_QA_VERSION", "system.band_names", ".geo", "LANDSAT_ID",
                  "system.footprint", "system.bands", "ESPA_VERSION",
                  "SR_APP_VERSION", "system.time_start", "system.version",
                  "LEVEL1_PRODUCTION_DATE", "system.asset_size", "system.id",
                  "SENSING_TIME", "EARTH_SUN_DISTANCE",
                  "IMAGE_QUALITY_OLI", "IMAGE_QUALITY_TIRS", "CLOUD_COVER_LAND")) %>%
        mutate(Date = str_sub(system.index, start = 15)) %>%
        mutate(
                Date = ifelse(SATELLITE == 'LANDSAT_7' | SATELLITE == 'LANDSAT_8',
                              str_sub(Date, start = 3), Date)
        ) %>%
        select(-("system.index")) %>%
        mutate(Date = as.Date(Date, "%Y%m%d")) %>%
        # mutate(Classe = ifelse(
        #         Date <= "2000-12-31", "Floresta", "Antropiza??o")) %>%
        rename(index = NDVI) %>%
        mutate(index_type = 'NDVI TEI 567028-C') %>%
        filter(!is.na(index)) 

## Summary of SAVI data frame in the TEI area
summary(ndvi_TEI_567028)

## NDVI forest metric TEI 567027
median(ndvi_TEI_567027[ndvi_TEI_567027$Date < '1988-09-08', 5])
sd(ndvi_TEI_567027[ndvi_TEI_567027$Date < '1988-09-08', 5])

## NDVI forest metric TEI 567028
sd(ndvi_TEI_567028[ndvi_TEI_567028$Date < '1988-09-08', 5])

#### Merge the Data Frames
df <- rbind(ndvi_TEI_567027, ndvi_TEI_567028)

min(df[df$Date < '1988-09-08', 5])

# df %>%
#         filter(Date >= '2012-01-01' & Date <= '2012-12-31') %>%
#         filter(index_type == 'NDVI TEI 567028-C') %>%
#         summarise(median(index))


## Save the new data frame as .csv file
write.csv2(
        df,
        './output/ndvi_1985-2020_dataset.csv',
        row.names = FALSE
)

## Set number of images by year
imgByYear <- df %>%
        filter(index_type == 'NDVI TEI 567028-C') %>%
        mutate(year = year(Date)) %>%
        group_by(year, SATELLITE) %>%
        summarise(n = n())

write.csv2(imgByYear, './output/imgByYear.csv', row.names = FALSE)

### Inference Statistic
CI <- function(vector, std, alpha) {
        
        # media do vetor de amostras
        mean <- mean(vector)
        
        # Obtem o valor da estatistica Z. Apenas o valor a direita 
        # da calda da distribuicao.
        Z <- abs(qnorm(alpha / 2))
        
        # obtem o erro maximo
        errorMax <- Z * std / sqrt(nrow(df))
        
        # Limite Inferior do Intervalo de Confianca
        li_ic <- mean - errorMax
        
        # Limite Superior do Intervalo de Confianca
        ls_ic <- mean + errorMax
        
        # Vetor do intervalo de confianca
        ic <- c(li_ic, ls_ic)
        
        # Show the Interval of Confidence
        ic
}

CI(as.vector(df$index), 0.1420695, 0.05)

####>> Plot <<####
#png('./output/index.png', width = 640)
st <- ggplot(df, aes(x = Date, y = index)) +
        geom_line() +
        # geom_smooth(
        #         aes(color = 'Regressão'), 
        #         method = "loess", 
        #         se = FALSE, 
        #         size = 1.2
        # ) +
        #geom_hline(yintercept = 0.4527116, color = 'red') +
        facet_wrap(~index_type, nrow = 2) +
        stat_valleys(color = "red", aes(color = "Baixas"), 
                     ignore_threshold = 0.6690257) +
        scale_colour_manual(values = c("red", "steelblue")) +
        scale_x_date(
                date_labels = "%Y",
                date_breaks = "24 month"
        ) +
        # # Set text label to 1988-09-24
        # annotate('text',
        #          x = as.Date('1988-09-24'), y = 0.05,
        #          label = 'Fogo de Sub-bosque', color = 'red', size = 3) +
        # # Set text label to 1998-09-04
        # annotate('text',
        #          x = as.Date('1998-09-04'), y = 0.05,
        #          label = 'Fogo de Sub-bosque', color = 'red', size = 3) +
        theme(
                axis.text.x = element_text(angle = 60, size = 13),
                axis.text.y = element_text(size = 13),
                plot.title = element_text(hjust = 0.5, size = 14, face = 'bold'),
                strip.text = element_text(size = 13),
                plot.subtitle = element_text(hjust = 0.5, size = 14)
        ) +
        labs(
                title = 'Comportamento Espectral de NDVI nas Áreas Embargadas',
                subtitle = 'Série Temporal 1985 a 2020',
                x = 'Série Temporal',
                y = 'NDVI',
                color = 'Legenda:'
        )

st

ggplotly(st)

#dev.off()

## BoxoPlot## 
df %>%
        filter(Date <= '1988-09-08' | Date >= '2010-01-01' & Date <= '2010-12-31') %>%
        mutate(class = ifelse(Date <= '1988-09-08', 'Floresta 1985-1988', 'Antropismo 2010')) %>%
        ggplot() +
        geom_boxplot(aes(class, index), outlier.color = "red", outlier.shape = 1) +
        #geom_density(aes(x = index, fill = class), alpha = 0.5) +
        #geom_violin(aes(x = index, y = class, color = class)) +
        facet_wrap(~index_type, ncol = 2) +
        #scale_x_date(date_breaks = '24 months', date_labels = '%Y') +
        ## Set arrow label to forest
        # annotate('curve',
        #          x = as.Date('1990-01-01'), y = 0.58, 
        #          xend = as.Date('1991-06-30'), yend = 0.7, 
        #          curvature = .3, 
        #          arrow = arrow(length = unit(2, 'mm'))
        # ) +
        ## Set arrow label to forest
        # annotate('curve',
        #          x = as.Date('1990-01-01'), y = 0.58, 
        #          xend = as.Date('2000-07-30'), yend = 0.65, 
        #          curvature = .3, 
        #          arrow = arrow(length = unit(2, 'mm'))
        # ) +
        ## Set text label to forest
        # annotate('text', 
        #          x = as.Date('1988-10-01'), y = 0.585, 
        #          label = 'Floresta') +
        # ## Set arrow label to deforestation
        # annotate('curve',
        #          x = as.Date('2003-01-01'), y = 0.5, 
        #          xend = as.Date('2007-06-30'), yend = 0.5, 
        #          arrow = arrow(length = unit(2, 'mm'))
        # ) +
        ## Set text label to deforestation
        # annotate('text', 
        #          x = as.Date('2001-02-25'), y = 0.5, 
        #          label = 'Supress?o') +
        # ## Set arrow label to forest regeneration
        # annotate('curve',
        #          x = as.Date('2015-01-01'), y = 0.56, 
        #          xend = as.Date('2018-06-30'), yend = 0.75, 
        #          arrow = arrow(length = unit(2, 'mm'))
        # ) +
        # ## Set text label to forest regeneration
        # annotate('text', 
        #          x = as.Date('2013-02-25'), y = 0.56, 
        #          label = 'Regenera??o') +
        theme(
                legend.position = 'bottom',
                legend.title = element_blank(),
                legend.box = 'horizontal',
                legend.background = element_rect(fill = 'lightgrey'),
                #legend.margin = margin(1, 1, 1, 1),
                #legend.box.margin = margin(40, 40, 40, 40),
                axis.title.y = element_text(size = 13, face = "bold"),
                axis.title.x = element_text(size = 13, face = "bold"),
                plot.title = element_text(hjust = 0.5, size = 14)
        ) +
        labs(
                title = 'NDVI nas Areas Embargadas',
                x = '',
                y = 'NDVI'
        ) 

### BoxPlot by year
df %>%
        mutate(year = lubridate::year(Date)) %>%
        ggplot() +
        geom_boxplot(aes(factor(year), index), outlier.color = "red", outlier.shape = 1) +
        #geom_density(aes(x = index, fill = class), alpha = 0.5) +
        #geom_violin(aes(x = index, y = class, color = class)) +
        facet_wrap(~index_type, nrow = 2) +
        geom_hline(yintercept = 0.4527116, color = 'red') +
        theme(
                legend.position = 'bottom',
                legend.title = element_blank(),
                legend.box = 'horizontal',
                legend.background = element_rect(fill = 'lightgrey'),
                #legend.margin = margin(1, 1, 1, 1),
                #legend.box.margin = margin(40, 40, 40, 40),
                axis.title.y = element_text(size = 13, face = "bold"),
                axis.title.x = element_text(size = 13, face = "bold"),
                axis.text.x = element_text(angle = 60),
                plot.title = element_text(hjust = 0.5, size = 14, face = 'bold')
        ) +
        labs(
                title = 'Distribuição do NDVI nas Áreas Embargadas',
                x = 'Série Temporal',
                y = 'NDVI'
        ) 
