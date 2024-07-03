box::use(arrow[...])
box::use(geoarrow[...])
box::use(dplyr[...])

box::use(AzureStor)

box::use(../R/utils[azure_endpoint_url])



es <- azure_endpoint_url()

# storage endpoint
se <- AzureStor$storage_endpoint(es, sas = Sys.getenv("DSCI_AZ_SAS_DEV") )

# storage container
sc_global <-  AzureStor$storage_container(se, "global")
tf <- tempfile(fileext = ".parquet")

# it's a sizeable file - currently we need to download the whole thing in R.
# arrow format allows querying in cloud, but no R bindings. Can do in python
# in duckdb we can query, but the geometries are not supported

AzureStor$download_blob(
  container = sc_global, 
  src = "vector/hybas_asia_basins.parquet",
  dest = tf,
  overwrite = TRUE
)

# df <- read_parquet(tf)

df <- open_dataset(tf) |> 
  filter(level %in% c("03","04")) |> 
  collect() |> 
  select(
    hybas_id,
    level,
    region,
    geometry
  )

sc_projects <- AzureStor::storage_container(se, "projects")
tf <- tempfile(fileext = ".parquet")
write_parquet(df,sink = tf)

AzureStor::upload_blob(
  container = sc_projects, 
  src = tf,
  dest = "ds-contingency-pak-floods/hybas_asia_basins_03_04.parquet"
)
