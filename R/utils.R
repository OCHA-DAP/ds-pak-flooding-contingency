#' @export
download_fieldmaps_sf <- function(iso3, layer = NULL) {
  iso3 <- tolower(iso3)
  download_shapefile(
    url = glue::glue("https://data.fieldmaps.io/cod/originals/{iso3}.gpkg.zip"),
    boundary_source = "FieldMaps",
    layer = layer
  )
}


#' Download shapefile and read
#'
#' Download shapefile to temp file, unzipping zip files if necessary. Deals with zipped
#' files like geojson or gpkg files as well as shapefiles, when the unzipping
#' returns a folder. The file is then read with `sf::st_read()`.
#'
#' @param url URL to download
#' @param layer Layer to read
#' @param iso3 `character` string of ISO3 code to add to the file.
#' @param boundary_source `character` name of source for the admin 0 boundaries
#'     layer. If supplied a column named "boundary_source"
#'     will added to sf object with the specified input. If `NULL` (default)
#'     no column added.
#'
#' @returns sf object
#'
#' @export
download_shapefile <- function(
    url,
    layer = NULL,
    iso3 = NULL,
    boundary_source = NULL) {
  if (stringr::str_ends(url, ".zip")) {
    utils::download.file(
      url = url,
      destfile = zf <- tempfile(fileext = ".zip"),
      quiet = TRUE
    )

    utils::unzip(
      zipfile = zf,
      exdir = td <- tempdir()
    )

    # if the file extension is just `.zip`, we return the temp dir alone
    # because that works for shapefiles, otherwise we return the file unzipped
    fn <- stringr::str_remove(basename(url), ".zip")
    if (tools::file_ext(fn) == "") {
      fn <- td
    } else {
      fn <- file.path(td, fn)
    }
  } else {
    utils::download.file(
      url = url,
      destfile = fn <- tempfile(fileext = paste0(".", tools::file_ext(url))),
      quiet = TRUE
    )
  }

  if (!is.null(layer)) {
    ret <- sf::st_read(
      fn,
      layer = layer,
      quiet = TRUE
    )
  } else {
    ret <- sf::st_read(
      fn,
      quiet = TRUE
    )
  }

  # add in iso3 and boundary source. if NULL, no change will happen
  ret$iso3 <- iso3
  ret$boundary_source <- boundary_source

  ret
}


#' @export
load_proj_contatiners <- function() {
  es <- azure_endpoint_url()
  # storage endpoint
  se <- AzureStor::storage_endpoint(es, sas = Sys.getenv("DSCI_AZ_SAS_DEV"))
  # storage container
  sc_global <- AzureStor::storage_container(se, "global")
  sc_projects <- AzureStor::storage_container(se, "projects")
  list(
    GLOBAL_CONT = sc_global,
    PROJECTS_CONT = sc_projects
  )
}

#' @export
azure_endpoint_url <- function(
    service = c("blob", "file"),
    stage = c("dev", "prod"),
    storage_account = "imb0chd0") {
  blob_url <- "https://{storage_account}{stage}.{service}.core.windows.net/"
  service <- rlang::arg_match(service)
  stage <- rlang::arg_match(stage)
  storae_account <- rlang::arg_match(storage_account)
  endpoint <- glue::glue(blob_url)
  return(endpoint)
}
