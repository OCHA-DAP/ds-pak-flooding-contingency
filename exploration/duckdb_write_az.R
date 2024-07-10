



library(duckdb)
library(arrow)
library(sf)
library(glue)


targets::tar_load(df_thresholds,store = "_targets")

con <- dbConnect(duckdb::duckdb())

dbExecute(con, "INSTALL azure;")
dbExecute(con, "LOAD 'azure';")

ACCOUNT_KEY = Sys.getenv("DSCI_AZ_DEV_ACCOUNT_KEY")
ACCOUNT_NAME = Sys.getenv("DSCI_AZ_STORAGE_ACCOUNT")
ddb_azure_connection <- glue("SET azure_storage_connection_string = 'DefaultEndpointsProtocol=https;AccountName={ACCOUNT_NAME};AccountKey={ACCOUNT_KEY};EndpointSuffix=core.windows.net';")


dbExecute(con, ddb_azure_connection)
dbGetQuery(con, "FROM duckdb_extensions()")

duckdb_register(con, "df_thresholds", df_thresholds)
duckdb::dbListTables(con)

df_query <- dbGetQuery(con,"SELECT * FROM df_thresholds" )
df_query
tbl_db <- dplyr::tbl(con, "df_thresholds")
tbl_db


dbExecute(
  con,
  "COPY (SELECT * FROM df_thresholds)
  TO  'azure://projects/ds-contingency-pak-floods/pak_imerg_flooding_thresholds.parquet'
  (FORMAT 'parquet');"
)
