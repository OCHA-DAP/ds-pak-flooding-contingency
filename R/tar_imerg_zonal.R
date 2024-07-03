

imerg_zonal <- function(fp_urls,aoi){
  fp_urls|> 
    map(
      \(url_tmp){
        cat(url_tmp,"\n")
        rtmp <- rast(url_tmp)
        exact_extract(
          x = rtmp,
          y = aoi,
          fun ="mean",
          force_df = TRUE,
          append_cols = colnames(aoi)
        ) |> 
          mutate(
            date = as_date(str_extract(url_tmp, "\\d{4}-\\d{2}-\\d{2}"))
          )
      }
    )  
  
}
