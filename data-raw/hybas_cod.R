

zf <- "/Users/zackarno/Downloads/pak_adm_wfp_20220909_shp.zip"
zf_vp <- paste0("/vsizip/",zf)

library(sf)
library(janitor)
library(tidyverse)
library(arrow)
library(geoarrow)
st_layers(zf_vp)

gdf_adm1 <- st_read(zf_vp,"pak_admbnda_adm1_wfp_20220909") |> 
  clean_names() |> 
  mutate(
    aoi_lgl = adm1_en == "Sindh"
  )


zf <- "/Users/zackarno/Downloads/hybas_as_lev01-12_v1c.zip"
zf_vp <- paste0("/vsizip/",zf)


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



gdf_adm2 <- sf::st_read(zf_vp,"afg_admbnda_adm2_agcho_20211117") |>
  janitor::clean_names() |>
  dplyr::select(matches("adm\\d_[pe]"))
?sf::st_read
"/Users/zackarno/Downloads/pak_adm_wfp_20220909_shp.zip
"/Users/zackarno/Downloads/pak_adm_wfp_20220909_shp/"
