# Load packages required to define the pipeline:
library(targets)
tar_source()


# Set target options:
tar_option_set(
  packages = c(
    "sf",
    "tidyverse",
    "terra",
    "janitor",
    "exactextractr"
  ) # Packages that your targets need for their tasks.
  
)


es <- azure_endpoint_url()

# storage endpoint
se <- AzureStor::storage_endpoint(es, sas = Sys.getenv("DSCI_AZ_SAS_DEV") )

# storage container
sc <-  AzureStor::storage_container(se, "global")

cog_folder_contents <- AzureStor::list_blobs(sc,dir = "imerg/v6")



az_prefix <- "/vsiaz/"
container <- "global/"
urls <- paste0(az_prefix,container, cog_folder_contents$name)

Sys.setenv(AZURE_STORAGE_SAS_TOKEN=Sys.getenv("DSCI_AZ_SAS_DEV"))
Sys.setenv(AZURE_STORAGE_ACCOUNT=Sys.getenv("DSCI_AZ_STORAGE_ACCOUNT"))



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

# Run the R scripts in the R/ folder with your custom functions:
tar_source()
# tar_source("other_functions.R") # Source other scripts as needed.

# Replace the target list below with your own:
list(
  tar_target(
    name = zfp_basins,
    command = "/Users/zackarno/Downloads/hybas_as_lev01-12_v1c.zip",
    format = "file"
  ),
  tar_target(
    name = gdf_basins,
    command=  load_basins(zip_file_path = zfp_basins)
  ),
  tar_target(
    name = gdf_adm1,
    command = download_fieldmaps_sf(iso3="pak",layer = "pak_adm1")
  ),
  tar_target(
    name= gdf_aoi_bas3,
    command = gdf_basins$level_3 |> 
      filter(
        hybas_id %in% BAS3_ID_AOI
      ) 
  ),
  tar_target(
    name= gdf_aoi_bas4,
    command = gdf_basins$level_4 |> 
      filter(
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
    command =bind_rows(
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
    command = imerg_zonal(fp_urls = urls,aoi = gdf_aoi_merged)
  ),

tar_target(
  name = df_aoi_zonal_roll_long,
  command = list_rbind(df_aoi_zonal) |> 
    roll_zonal_stats() |> 
    add_smoothed_mean(k=10)
),
tar_target(
  name = df_quantiles,
  command = df_aoi_zonal_roll_long |> 
    yearly_max() |> 
    grouped_quantile_summary(
      x= "value",
      grp_vars = c("aoi","name"),
      rps= 1:10
    )
),
tar_target(
  name = df_thresholds,
  command = df_quantiles |> 
    filter(
      aoi == "basin_4",
      name == "3d",
      rp == 5
    )
  
)
  
)
