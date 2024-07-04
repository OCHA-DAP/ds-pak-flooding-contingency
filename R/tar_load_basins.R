library(geoarrow)
library(arrow)
source("R/utils.R")



#' load basins levels 3 & 4 created in data-raw/03_subset_basins.R
#'
#' @return sf object
load_basins <-  function(){
  pc <- load_proj_contatiners()
  tf <- tempfile(fileext = ".parquet")
  AzureStor::download_blob(
    container = pc$PROJECTS_CONT,
    src = "ds-contingency-pak-floods/hybas_asia_basins_03_04.parquet",
    dest = tf
  )
  
  open_dataset(tf) |> 
    sf::st_as_sf() |> 
    sf::st_make_valid()
  
  
}