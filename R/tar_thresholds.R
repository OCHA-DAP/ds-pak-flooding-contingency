# target specific functions for running historical analysis
# and threshold setting in the pipeline
source("R/utils.R")


roll_zonal_stats <- function(df) {
  df |>
    rename(
      `1d` = mean
    ) |>
    group_by(aoi) |>
    arrange(aoi, date) |>
    mutate(
      `2d` = zoo::rollsum(x = `1d`, k = 2, fill = NA, align = "right"),
      `3d` = zoo::rollsum(x = `1d`, k = 3, fill = NA, align = "right"),
    ) |>
    pivot_longer(cols = c("1d", "2d", "3d"))
}


add_smoothed_mean <- function(df, k = 10) {
  df |>
    arrange(aoi, name, date) |>
    group_by(
      aoi, name
    ) |>
    mutate(
      doy = day(date),
      smoothed = zoo::rollmean(x = value, k = k, fill = NA, align = "right"),
    ) |>
    group_by(
      doy,
      .add = TRUE
    ) |>
    mutate(
      avg_smooth =  mean(smoothed),
      anom = smoothed - avg_smooth,
      std_anom = anom / sd(smoothed)
    ) |>
    ungroup()
}

yearly_max <- function(df) {
  df |>
    mutate(
      yr_date = floor_date(date, "year")
    ) |>
    group_by(aoi, yr_date, name) |>
    summarise(
      value = max(value, na.rm = TRUE),
      anom = max(anom, na.rm = TRUE),
      std_anom = max(std_anom, na.rm = TRUE),
    )
}



# function
grouped_quantile_summary <- function(df,
                                     x,
                                     grp_vars,
                                     rps = c(1:10)) {
  df %>%
    group_by(
      across(all_of(grp_vars))
    ) %>%
    reframe(
      rp = rps,
      q = 1 / rp,
      q_val = quantile(.data[[x]], probs = 1 - (1 / rp))
    )
}


#' select_thresholds
#' convenience function to filter  thresholds to desired RP and then write
#' data.frame to blob as parquet for use in monitoring
#' @param df data.frame (`df_quantiles` from _targets.r) containing thresholds
#'  for each RP/quantile value
#' @param write_blob logical (default = TRUE). If TRUE data.frame will be
#'   written to blob as .parquet file
#'
#' @return data.frame
select_final_thresholds <- function(
    df,
    write_blob = T,
    v = 2025) {
  df_sel <- df |>
    filter(
      aoi == "basin_4",
      name == "3d",
      rp == 5
    )
  if (write_blob) {
    if(v==2024){
      cont <- load_proj_contatiners()$PROJECTS_CONT
      tf <- tempfile(fileext = ".parquet")
      write_parquet(
        x = df_sel,
        sink = tf
      )
      AzureStor::upload_blob(
        container = cont,
        src = tf,
        dest = "ds-contingency-pak-floods/imerg_flooding_thresholds.parquet",
      )
    }
  if(v==2025){
    cumulus::blob_write(
      df_sel,
      container = "projects",
      name = "ds-contingency-pak-floods/imerg_flooding_thresholds_2025.parquet",
      
    )
  }
  }

  df_sel
}
