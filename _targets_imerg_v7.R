# tar_config_set(script = "_targets.R", store = "_targets", project = "pak_imerg_2024")
# tar_config_set(script = "_targets_imerg_v7.R", store = "_targets_2025", project = "pak_imerg_2025")
# Sys.setenv(TAR_PROJECT = "pak_imerg_2025")

#' Targets analysis pipeline
#' The zonal stats (`imerg_zonal()`) could take anywhere from 20 minutes
#' to an hour depending on your connection. Therefore you may want to run this
#' code as a background process. On mac use the terminal to navigate to the 
#' repo root and run:
#' caffeinate -i -s Rscript -e 'Sys.setenv(TAR_PROJECT = "pak_imerg_2025"); targets::tar_make()'

library(targets)
tar_source()


# Set target options:
tar_option_set(
  packages = c(
    "sf",
    "tidyverse",
    "terra",
    "janitor",
    "exactextractr",
    "arrow",
    "cumulus"
  ) # Packages that your targets need for their tasks.
)


pc <- cumulus::blob_containers(stage=  "prod", write =FALSE)
# pc <- load_proj_contatiners()



cog_folder_contents <- AzureStor::list_blobs(pc$raster, dir = "imerg/daily/late/v7/processed")

az_prefix <- "/vsiaz/"
container <- "raster/"
urls <- paste0(az_prefix, container, cog_folder_contents$name)


# necessary for GDAL + AZURE Connection (terra)
Sys.setenv(AZURE_STORAGE_SAS_TOKEN = cumulus:::get_sas_key(stage = "prod", write_acces = FALSE))
Sys.setenv(AZURE_STORAGE_ACCOUNT = "imb0chd0prod")


BAS4_ID_AOI <- c(
  4040033440,
  4040033650,
  4040879040,
  4040879050,
  4040033440,
  4040033640
)

BAS3_ID_AOI <- c(
  4030033640
)


# Replace the target list below with your own:
list(
  # tar_target(
  #   name = zfp_basins,
  #   command = "/Users/zackarno/Downloads/hybas_as_lev01-12_v1c.zip",
  #   format = "file"
  # ),
  tar_target(
    name = gdf_basins,
    command = load_basins(v_year =2025)
  ),
  tar_target(
    name = gdf_adm1,
    command = download_fieldmaps_sf(iso3 = "pak", layer = "pak_adm1")
  ),
  tar_target(
    name = gdf_aoi_bas3,
    command = gdf_basins |>
      filter(
        level == "03",
        hybas_id %in% BAS3_ID_AOI
      )
  ),
  tar_target(
    name = gdf_aoi_bas4,
    command = gdf_basins |>
      filter(
        level == "04",
        hybas_id %in% BAS4_ID_AOI
      ) |>
      summarise()
  ),
  
  # Zonal STats -------------------------------------------------------------
  
  
  # since retrieving the rasters is the time-limiting step in zonal extraction
  # much faster to merge AOI options into MULTIPOLYGON and run zonal stats
  # for both at once
  tar_target(
    name = gdf_aoi_merged,
    command = bind_rows(
      gdf_aoi_bas3 |>
        transmute(
          aoi = "basin_3"
        ),
      gdf_aoi_bas4 |>
        transmute(
          aoi = "basin_4"
        )
    )
  ),
  tar_target(
    name = df_aoi_zonal,
    command = imerg_zonal(fp_urls = urls, aoi = gdf_aoi_merged)
  ),
  tar_target(
    name = df_aoi_zonal_roll_long,
    command = list_rbind(df_aoi_zonal) |>
      roll_zonal_stats() |>
      add_smoothed_mean(k = 10)
  ),
  tar_target(
    name = df_quantiles,
    command = df_aoi_zonal_roll_long |>
      yearly_max() |>
      grouped_quantile_summary(
        x = "value",
        grp_vars = c("aoi", "name"),
        rps = 1:10
      )
  ),
  tar_target(
    name = df_thresholds,
    command = select_final_thresholds(df_quantiles, write_blob = TRUE),
    description = "Select final thresholds based on 5 year RP of 3d rainfall values for the AOI (Basin 4 merged and subset)"
  )
)
