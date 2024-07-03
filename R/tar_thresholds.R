# tar_thresholds

roll_zonal_stats <- function(df){
  df |> 
    rename(
      `1d` = mean
    ) |>
    group_by(aoi) |> 
    arrange(aoi,date) |> 
    mutate(
      `2d` = zoo::rollsum(x = `1d`, k=2, fill = NA, align = "right"),
      `3d` = zoo::rollsum(x = `1d`, k=3, fill = NA, align = "right"),
    ) |> 
    pivot_longer(cols = c("1d","2d","3d"))
} 


add_smoothed_mean <- function(df, k= 10){
  df |> 
    arrange(aoi, name, date) |> 
    group_by(
      aoi, name
    ) |> 
    mutate(
      doy = day(date),
      smoothed = zoo::rollmean(x = value, k=k, fill = NA, align = "right"),
    ) |> 
    group_by(
      doy,
      .add=TRUE
    ) |> 
    mutate(
      avg_smooth =  mean(smoothed),
      anom = smoothed - avg_smooth,
      std_anom = anom/sd(smoothed)
    ) |> 
    ungroup()
} 

yearly_max <- function(df){
  df |> 
    mutate(
      yr_date = floor_date(date, "year")
    ) |> 
    group_by(aoi,yr_date,name) |> 
    summarise(
      value = max(value,na.rm = TRUE),
      anom = max(anom,na.rm = TRUE),
      std_anom = max(std_anom,na.rm = TRUE),
    )
  
}



# function 
grouped_quantile_summary <- function(df,
                                     x ,
                                     grp_vars,
                                     rps = c(1:10)) {
  df %>%
    group_by(
      across(all_of(grp_vars))
    ) %>%
    reframe(
      rp = rps,
      q = 1 / rp,
      q_val = quantile(.data[[x]], probs = 1-(1 / rp))
    )
}

# df_rp_thresholds <- df_roll_max |> 
#   grouped_quantile_summary(
#     x= "value",
#     grp_vars = c("aoi","name"),
#     rps= 1:10
#   )
# 
# 
# df_rp_threshold_filt<- df_rp_thresholds |> 
#   filter(rp %in% c(3,4,5)) |> 
#   select(aoi,name,rp, threshold = q_val) 