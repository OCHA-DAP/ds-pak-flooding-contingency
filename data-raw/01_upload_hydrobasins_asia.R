#' Script to write out entire hydrobasins asia dataset to parquet file
#' and store on blob. 
library(sf)
library(janitor)
library(tidyverse)
library(arrow)
library(geoarrow)


# I guess i could put the raw zip on the blob and download it as a tempfile,
# but seems a bit annoying since im just running this once. Adding it as a **TODO**

zf <- "/Users/zackarno/Downloads/hybas_as_lev01-12_v1c.zip"
zf_vp <- paste0("/vsizip/",zf)

st_layers(zf_vp)

gdf_basins <- st_layers(zf_vp)$name |> 
  map(
    \(lyr_nm){
      st_read(zf_vp, lyr_nm) |> 
        clean_names() |> 
        mutate(
          level = str_extract(lyr_nm,"\\d{2}"),
          region = "Asia"
        )
    }
  ) |> 
  list_rbind()


cumulus::write_az_file(gdf_basins, container = "global","vector/hybas_asia_basins.parquet")
