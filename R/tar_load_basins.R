library(geoarrow)
library(cumulus)
source("R/utils.R")


#' load basins levels 3 & 4 created in data-raw/03_subset_basins.R
#'
#' @return sf object
load_basins <- function(v_year = 2025) {
  if(v_year ==2025){
    container_ob <- cumulus::blob_containers(stage = "dev",write_access= FALSE)$projects
  }
  if(v_year == 2024){
    container_ob <- load_proj_contatiners()$PROJECTS_CONT
  }
  
  tf <- tempfile(fileext = ".parquet")
  AzureStor::download_blob(
    container = container_ob,
    src = "ds-contingency-pak-floods/hybas_asia_basins_03_04.parquet",
    dest = tf
  )

  arrow::open_dataset(tf) |>
    sf::st_as_sf() |>
    sf::st_make_valid()
}
