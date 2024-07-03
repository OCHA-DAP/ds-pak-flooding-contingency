


load_basins <-  function(zip_file_path=zfp_basins){
  map(
    c(level_3= "hybas_as_lev03_v1c",
      level_4= "hybas_as_lev04_v1c") , \(lyr_nm){
        st_read(
          paste0("/vsizip/",zip_file_path), lyr_nm,quiet=T
          ) |> 
            clean_names() |> 
            mutate(
              level = str_extract(lyr_nm,"\\d{2}"),
              region = "Asia"
            ) |> 
            st_make_valid()
        
      }
  )
}
