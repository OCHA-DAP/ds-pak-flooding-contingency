#' imerg_zonal
#'
#' @param fp_urls character vector of blob urls containing paths to COG rasters.
#' @param aoi polyon(s) containing AOI of interest
#'
#' @return data.frame with zonal stats per AOI strata across all COGs

imerg_zonal <- function(fp_urls, aoi) {
  fp_urls |>
    map(
      \(url_tmp){
        cat(url_tmp, "\n")
        rtmp <- rast(url_tmp)
        exact_extract(
          x = rtmp,
          y = aoi,
          fun = "mean",
          force_df = TRUE,
          append_cols = colnames(aoi)
        ) |>
          mutate(
            date = as_date(str_extract(url_tmp, "\\d{4}-\\d{2}-\\d{2}"))
          )
      }
    )
}
