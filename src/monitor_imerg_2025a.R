box::use(
  terra[...],
  arrow[...],
  gghdx[...],
  geoarrow[...],
  sf[...],
  ggplot2[...],
  lubridate[...],
  dplyr[...],
  stringr[...],
  gghdx[...],
  tidyr[...],
  glue[...],
  blastula[...],
  zoo[...]
  
  )

box::use(
  exactextractr,
  AzureStor, 
  cumulus,
  logger
)


# box::use(../R/utils[azure_endpoint_url,load_proj_contatiners])
box::use(btools=../src/email_utils)
gghdx()

is_test_email <- as.logical(Sys.getenv("TEST_EMAIL", unset = TRUE))

extract_date <- function(x) {
  as_date(
    str_extract(
      x,
      "\\d{4}-\\d{2}-\\d{2}"
    )
  )
}

# AOI Basins --------------------------------------------------------------

BAS4_ID_AOI <- c(
  4040033440,
  4040033650,
  4040879040,
  4040879050,
  4040033440,
  4040033640
)


# Set required env vars for terra::rast -----------------------------------

# Oddly, on my computer i need to un-comment these to run OR I think I could
# add `AZURE_SAS` + `AZURE_STORAGE_ACCOUNT` to `.Renviron`. Oddly,Setting the
# Sys.env vars like this on the GHA runner does not work even if I
# have `DSCI_AZ_SAS_DEV` + `DSCI_AZ_STORAGE_ACCOUNT` already stored as secrets
# I still need to to have  AZURE_SAS + `AZURE_STORAGE_ACCOUNT` stored 
# separately. I think it could be due to a newer version of gdal on runner w/
# slighly different requirements for accessing azure storage.

Sys.setenv(AZURE_SAS = Sys.getenv("DSCI_AZ_BLOB_PROD_SAS"))
# Sys.setenv(AZURE_STORAGE_ACCOUNT = Sys.getenv("DSCI_AZ_STORAGE_ACCOUNT"))
Sys.setenv(AZURE_STORAGE_ACCOUNT = "imb0chd0prod")

names(Sys.getenv())

# Create container end points ---------------------------------------------
# pc <- load_proj_contatiners()

# Load thresholds data.frame ----------------------------------------------


# tf <- tempfile(fileext = "csv")
# 
# AzureStor$download_blob(
#   container = pc$PROJECTS_CONT,
#   src = "ds-contingency-pak-floods/pak_monitoring_email_receps.csv",
#   dest = tf
# )

df_receps <- cumulus$blob_read(
  container = "projects",
  name = "ds-contingency-pak-floods/pak_monitoring_email_receps.csv"
  
)
# df_receps <- read.csv(tf)
df_receps <- df_receps |> 
  mutate(
    Frequency = trimws(tolower(Frequency))
  )
df_receps <- df_receps |> 
  filter(test)

# Load thresholds data.frame ----------------------------------------------

# 
# tf <- tempfile(fileext = ".parquet")
# 
# AzureStor$download_blob(
#   container = pc$PROJECTS_CONT,
#   src = "ds-contingency-pak-floods/imerg_flooding_thresholds.parquet",
#   dest = tf
# )

# df_thresholds_24 <- cumulus$blob_read(
#     container = "projects",
#     name =  "ds-contingency-pak-floods/imerg_flooding_thresholds.parquet",
#   )
logger$log_info("reading thresholds")

df_thresholds_25 <- cumulus$blob_read(
    container = "projects",
    name =  "ds-contingency-pak-floods/imerg_flooding_thresholds_2025.parquet",
  )


# df_thresholds <- read_parquet(tf)


# load aoi geodata --------------------------------------------------------
logger$log_info("Read basin geographies")

tf <- tempfile(fileext = ".parquet")
# AzureStor$download_blob(
#   container = pc$PROJECTS_CONT,
#   src = "ds-contingency-pak-floods/hybas_asia_basins_03_04.parquet",
#   dest = tf
# )

pc <- cumulus$blob_containers(stage ="dev")
AzureStor$download_blob(
  container =pc$projects,
  src = "ds-contingency-pak-floods/hybas_asia_basins_03_04.parquet",
  dest = tf
)
gdf_aoi_bas4 <- open_dataset(tf) |>
  filter(
    level == "04",
    hybas_id %in% BAS4_ID_AOI
  ) |>
  st_as_sf() |>
  st_make_valid() |>
  summarise()


# Load IMERG Rasters ------------------------------------------------------


logger$log_info("Init Prod Container")
prod_containers <- cumulus$blob_containers(
  stage = "prod",
  write_access = FALSE
  )


logger$log_info("Scan prod container for relevant rasters")
cog_folder_contents <- AzureStor$list_blobs(prod_containers$raster, dir = "imerg/daily/late/v7/processed")

cog_tbl <- cog_folder_contents |>
  mutate(
    date = extract_date(name)
  )

last_10_dates <- seq(max(cog_tbl$date) - 9, max(cog_tbl$date), by = "day")

az_prefix <- "/vsiaz/raster/"

az_urls <- cog_tbl |>
  filter(
    date %in% last_10_dates
  ) |>
  mutate(
    az_url = paste0(az_prefix, name)
  ) |>
  pull(az_url)


logger$log_info("Read rasters")
r <- rast(az_urls, win = gdf_aoi_bas4)
names(r) <- extract_date(sources(r))


# Zonal Stats -------------------------------------------------------------

df_zonal <- exactextractr$exact_extract(
  x = r,
  y = gdf_aoi_bas4,
  fun = "mean",
  force_df = TRUE,
  append_cols = colnames(gdf_aoi_bas4)
) |>
  pivot_longer(everything()) |>
  mutate(
    date = extract_date(name)
  ) |>
  arrange(date)

df_zonal_processed <- df_zonal |>
  mutate(
    `3d` = rollsum(x = value, k = 3, fill = NA, align = "right"),
    alert_flag = `3d` >= df_thresholds$q_val
  )



# Plot --------------------------------------------------------------------

p <- df_zonal_processed |>
  filter(!is.na(`3d`)) |>
  ggplot(
    aes(x = date, y = `3d`)
  ) +
  geom_line() +
  geom_point() +
  geom_hline(
    yintercept = df_thresholds_25$q_val,
    color = hdx_hex("tomato-hdx"),
    linetype = "dashed"
  ) +
  annotate(
    geom = "text",
    x = max(df_zonal_processed$date) - 2,
    y = df_thresholds$q_val + 5,
    label = glue("Threshold (5 year RP value): {round(df_thresholds$q_val,0)} mm"),
    size = 6
  ) +
  scale_x_date(
    date_breaks = "day", date_labels = "%b %d"
  ) +
  labs(
    title = "Cumulative 3-day Precipitation",
    subtitle = "Pakistan: Lower Indus Basin Surrounding Sindh Province",
    y = "Precipitation (mm)",
    caption = glue("Data source: IMERG\nProduced {Sys.Date()} ")
  ) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(add = c(0, 10)))+
  theme(
    axis.title.x = element_blank(),
    axis.title.y = element_text(size = 14),
    axis.text.x = element_text(size = 14),
    plot.title = element_text(size = 20),
    plot.subtitle = element_text(size = 16)
  )


is_alert <- any(df_zonal_processed$alert_flag, na.rm = T)

run_date <- Sys.Date()
email_txt <- list()

email_txt$subj_status <- ifelse(is_alert, "Alert", "No Alert")
# make it colored in body
email_txt$body_status <- ifelse(is_alert, "<span style='color: #F2645A;'>Alert</span>", "<span style='color: #55b284ff;'>No Alert</span>")


email_txt$subject <- glue("Pakistan - Lower Indus Basin Rainfall Monitoring - {email_txt$subj_status} ({trimws(format(run_date, '%e %B'))})")

email_rmd_fp <- "email_pak_monitor.Rmd"
# Load in e-mail credentials
email_creds <- creds_envvar(
  user = Sys.getenv("CHD_DS_EMAIL_USERNAME"),
  pass_envvar = "CHD_DS_EMAIL_PASSWORD",
  host = Sys.getenv("CHD_DS_HOST"),
  port = Sys.getenv("CHD_DS_PORT"),
  use_ssl = TRUE
)

if(is_test_email){
  to_email <- df_receps[df_receps$test,"Email Address"]
} else if(!is_test_email){
  if(is_alert){
    to_email <- df_receps |> 
      filter(
        Frequency == "alerts"
      ) |> 
      pull(
        Email.Address
      )
  } else if(!is_alert) {
    to_email <- df_receps |> 
      filter(
        Frequency == "daily"
      ) |> 
      pull(`Email Address`)
    
  }
}

email_knitted <- render_email(
  input = email_rmd_fp,
  envir = parent.frame()
) 

smtp_send(
  email_knitted,
  from = "data.science@humdata.org",
  to = to_email,
  subject = email_txt$subject,
  credentials = email_creds
)



# one-off -----------------------------------------------------------------

# 
# 
# gdf_adm1 <- download_fieldmaps_sf(iso3="pak",layer = "pak_adm1")
# adm1_pcode <- gdf_adm1 |> 
#   filter(ADM1_EN =="Khyber Pakhtunkhwa") |> 
#   pull(ADM1_PCODE)
# con_prod <- cumulus::pg_con(stage= "prod")
# DBI:::dbListTables(con_prod)
# cumulus::pg_load_seas5_historical()
# 
# df_imerg_adm1 <- dplyr::tbl(con_prod, "imerg") |> 
#   filter(
#     adm_level ==1,
#     pcode ==adm1_pcode
#     ) |> 
#   collect()
# 
# 
# 
#   df_adm1_roll <- df_imerg_adm1 |>
#   rename(
#     `1d` = mean
#   ) |>
#   arrange( valid_date) |>
#   mutate(
#     `2d` = zoo::rollsum(x = `1d`, k = 2, fill = NA, align = "right"),
#     `3d` = zoo::rollsum(x = `1d`, k = 3, fill = NA, align = "right"),
#   ) |>
#   pivot_longer(
#     cols = c("1d", "2d", "3d"),names_to= "name",
#     values_to = "value"
#     
#     ) 
# 
#   df_adm1_thresh <- df_adm1_roll |>
#     mutate(
#       yr_date = floor_date(valid_date, "year")
#     ) |> 
#     group_by(yr_date, name) |>
#     summarise(
#       value = max(value, na.rm = TRUE)
#     ) |> 
#     grouped_quantile_summary(
#       x = "value",
#       grp_vars = c( "name"),
#       rps = 1:10
#     ) |> 
#     filter(name == "3d",
#            rp ==5)
#   
#   
#   df_adm1_roll_filt <- df_adm1_roll |> 
#     filter(
#       valid_date %in%     last_10_dates[-c(1,2)],
#       name == "3d"
#     ) 
#   df_adm1_roll_filt |> 
#     ggplot(
#       aes(x= valid_date, y= value)
#     )+
#     geom_line()+
#     geom_point()+
#     geom_hline(yintercept = df_adm1_thresh$q_val,
#                color = hdx_hex("tomato-hdx"),
#                linetype = "dashed"
#     ) +
#     annotate(
#       geom = "text",
#       x = max(df_adm1_roll_filt$valid_date) - 2,
#       y = df_adm1_thresh$q_val + 5,
#       label = glue("Threshold (5 year RP value): {round(df_adm1_thresh$q_val,0)} mm"),
#       size = 6
#     ) +
#     scale_x_date(
#       date_breaks = "day", date_labels = "%b %d"
#     ) +
#     labs(
#       title = "Cumulative 3-day Precipitation",
#       subtitle = "Pakistan: Khyber Pakhtunkhwa Province",
#       y = "Precipitation (mm)",
#       caption = glue("Data source: IMERG\nProduced {Sys.Date()} ")
#     ) +
#     scale_y_continuous(limits = c(0, NA), expand = expansion(add = c(0, 10)))+
#     theme(
#       axis.title.x = element_blank(),
#       axis.title.y = element_text(size = 14),
#       axis.text.x = element_text(size = 14),
#       plot.title = element_text(size = 20),
#       plot.subtitle = element_text(size = 16)
#     )
#   
#     
#     
