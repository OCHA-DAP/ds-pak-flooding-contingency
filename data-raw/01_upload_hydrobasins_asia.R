#' Script to write out entire hydrobasins asia dataset to parquet file
#' and store on blob. 
library(sf)
library(janitor)
library(tidyverse)
library(arrow)
library(geoarrow)
source("R/utils.R")


# I guess i could put the raw zip on the blob and download it as a tempfile,
# but seems a bit annoying since im just running this once. Adding it as a **TODO**

es <- azure_endpoint_url()
# storage endpoint
se <- AzureStor::storage_endpoint(es, sas = Sys.getenv("DSCI_AZ_SAS_DEV"))
# storage container
sc_global <- AzureStor::storage_container(se, "global")


# Load thresholds data.frame ----------------------------------------------


tf <- tempfile(fileext = ".zip")

AzureStor$download_blob(
  container = sc_global,
  src = "vector/hybas_as_lev01-12_v1c.zip",
  dest = tf
)

zf_vp <- paste0("/vsizip/",tf)
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
