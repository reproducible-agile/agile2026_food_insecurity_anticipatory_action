library(sf)
library(terra)
library(exactextractr)
library(dplyr)
library(mapview)
library(lubridate)

# -------- Join IPC monthly timeseries with admin 2 units -----------
# --------------------------------------------------------------------

# Load data
ipc <- st_read("data/intermediate/IPC_all_long_ts.gpkg", quiet = TRUE)
admin <- st_read("data/som_admin2.geojson", quiet = TRUE) %>%
  select(adm2_name, adm2_pcode, geometry)

# Format date column for naming
ipc$month <- format(ipc$month, "%Y-%m-%d")

# Convert to terra vector
ipc_vect <- vect(ipc)

# Unique month/scenario groups for rasterization
months_all <- unique(ipc_vect$month)
scenarios  <- unique(ipc_vect$scenario)

ipc_adm2_ts <- data.frame()
out_dir <- "data/intermediate/ipc_monthly_rasters"
if (!dir.exists(out_dir)) dir.create(out_dir)

# ---------- Create Raster for each scenario for each month and perform zonal stats on adm 2 level ------------
for (m in months_all) {
  for (s in scenarios) {

    sub <- ipc_vect[ipc_vect$month == m & ipc_vect$scenario == s, ]
    if (nrow(sub) == 0) next

    cat("Rasterizing:", s, m, "\n")

    # Rasterization
    r_template <- rast(sub, res = 0.01)
    r_phase <- rasterize(sub, r_template, field = "phase")
    #plot(r_phase, main = paste("Phase", s, m))

    # Save raster
    fname <- file.path(out_dir, paste0(s, "_", m, ".tif"))
    writeRaster(r_phase, fname, overwrite = TRUE)

    # Zonal stats for IPC majority and mean value per adm2 unit
    admin_r <- st_transform(admin, crs(r_phase))
    maj <- exact_extract(r_phase, admin_r, "majority")
    mean_val <- exact_extract(r_phase, admin_r, "mean")

    # Build df
    df <- data.frame(
      adm2_name  = admin_r$adm2_name,
      adm2_pcode = admin_r$adm2_pcode,
      scenario   = s,
      month      = m,
      phase_majority = maj,
      phase_mean = mean_val
    )

    ipc_adm2_ts <- rbind(ipc_adm2_ts, df)
  }
}



# -------- Join IPC phase on period level with admin 2 units -----------
# ----------------------------------------------------------------------

# Load data
ipc_p <- st_read("data/intermediate/IPC_all_long.gpkg", quiet = TRUE)

# Output folder
out_dir <- "data/intermediate/ipc_period_rasters"
if (!dir.exists(out_dir)) dir.create(out_dir)

# Convert to full date format
ipc_p$start <- as.Date(lubridate::my(ipc_p$start))
ipc_p$end   <- as.Date(lubridate::my(ipc_p$end))

# Group for disting scenario period combination
groups <- ipc_p %>%
  st_drop_geometry() %>%
  distinct(scenario, start, end)

ipc_adm2_period <- data.frame()


# ---------- Create rasters for each periods and perform zonal stats on adm 2 level ------------

for (i in seq_len(nrow(groups))) {

  # Select scenario and period start end for iteration
  s  <- groups$scenario[i]
  st <- groups$start[i]
  en <- groups$end[i]

  sub <- ipc_p[
    ipc_p$scenario == s &
      ipc_p$start == st &
      ipc_p$end == en, ]

  if (nrow(sub) == 0) next

  cat("Rasterizing", s, st, en, "\n")

  # Rasterization
  sub_vect <- vect(sub)
  r_template <- rast(sub_vect, res = 0.01)
  r_phase <- rasterize(sub_vect, r_template, field = "phase")
  #plot(r_phase, main = paste("Phase", s, st, "-", en))

  # Save raster with scenario + period in file name
  fname <- file.path(
    out_dir,
    paste0(s, "_", format(st, "%Y-%m-%d"), "_", format(en, "%Y-%m-%d"), ".tif")
  )
  writeRaster(r_phase, fname, overwrite = TRUE)

  # Zonal stats for majority and mean
  admin_r <- st_transform(admin, crs(r_phase))
  maj  <- exact_extract(r_phase, admin_r, "majority")
  mean_val <- exact_extract(r_phase, admin_r, "mean")

  # Build dataframe
  df <- data.frame(
    adm2_name  = admin_r$adm2_name,
    adm2_pcode = admin_r$adm2_pcode,
    scenario   = s,
    start      = st,
    end        = en,
    phase_majority = maj,
    phase_mean     = mean_val
  )

  ipc_adm2_period <- rbind(ipc_adm2_period, df)
}


# ---------- Fill a few NA districts with neighboring values ------------
# ----------------------------------------------------------------------

## ------ Monthly time series: join geometries and fill NAs from nearest polygon ------

# join geometries to the ts table
ipc_adm2_ts_sf <- admin %>%
  left_join(
    ipc_adm2_ts %>% select(-adm2_name),   # remove name so it isn't duplicated
    by = "adm2_pcode"
  ) 

# fill NAs per (start, end) period
ipc_adm2_ts_sf <- ipc_adm2_ts_sf %>%
  group_by(scenario, month) %>%   # <-- this replaces group_by(period)
  do({
    x <- .
    
    # rows that have both values vs. none
    has_value <- !is.na(x$phase_majority) & !is.na(x$phase_mean)
    no_value  <-  is.na(x$phase_majority) &  is.na(x$phase_mean)
    
    if (any(no_value) && any(has_value)) {
      centroids <- st_centroid(x)
      
      nn_index <- st_nearest_feature(
        centroids[no_value, ],
        centroids[has_value, ]
      )
      
      x$phase_majority[no_value] <- x$phase_majority[has_value][nn_index]
      x$phase_mean[no_value]     <- x$phase_mean[has_value][nn_index]
    }
    
    x
  }) %>%
  ungroup()



# write outputs
ipc_adm2_ts_out <- ipc_adm2_ts_sf %>% 
  st_as_sf() %>%     
  st_drop_geometry() %>%
  as.data.frame()       

write.csv(ipc_adm2_ts_out, "data/outputs/ipc_adm2_ts.csv", row.names = FALSE)


## ---- Period time series: join geometries and fill NAs from nearest polygon ----

# join geometries to the period table
ipc_adm2_period_sf <- admin %>%
  left_join(
    ipc_adm2_period %>% select(-adm2_name),   # keep name from admin only
    by = "adm2_pcode"
  )

# fill NAs per (scenario, start, end) group
ipc_adm2_period_sf <- ipc_adm2_period_sf %>%
  group_by(scenario, start, end) %>%
  do({
    x <- .
    
    has_value <- !is.na(x$phase_majority) & !is.na(x$phase_mean)
    no_value  <-  is.na(x$phase_majority) &  is.na(x$phase_mean)
    
    if (any(no_value) && any(has_value)) {
      centroids <- st_centroid(x)
      
      nn_index <- st_nearest_feature(
        centroids[no_value, ],
        centroids[has_value, ]
      )
      
      x$phase_majority[no_value] <- x$phase_majority[has_value][nn_index]
      x$phase_mean[no_value]     <- x$phase_mean[has_value][nn_index]
    }
    
    x
  }) %>%
  ungroup()

# drop geometry and write CSV
ipc_adm2_period_out <- ipc_adm2_period_sf %>%
  st_as_sf() %>%        # ensure sf
  st_drop_geometry() %>%
  as.data.frame()

write.csv(ipc_adm2_period_out, "data/outputs/ipc_adm2_period.csv", row.names = FALSE)




