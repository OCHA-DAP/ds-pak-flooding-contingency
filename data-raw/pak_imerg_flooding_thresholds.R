# write data.frame/tibble containing thresholds created by _targets.R
# pipeline to .parquet file in blob container for easy programmatic access
# for monitoring.

# Note - I decided not to use cumulus, a package we are developing for for azure
# remote storage connections as I am still experimenting with the simplest ways
# to connect that could later be integrated into cumulus

library(arrow)
library(tidyverse)
targets::tar_load(df_thresholds)
targets::tar_source()

es <- azure_endpoint_url()

# storage endpoint
se <- AzureStor::storage_endpoint(es, sas = Sys.getenv("DSCI_AZ_SAS_DEV") )

# storage container
sc <-  AzureStor::storage_container(se, "projects")
tf <- tempfile(fileext = ".parquet")

write_parquet(
  x = df_thresholds,
  sink = tf
)

AzureStor::upload_blob(
  container = sc,
  src = tf,
  dest = "ds-contingency-pak-floods/imerg_flooding_thresholds.parquet",
)
