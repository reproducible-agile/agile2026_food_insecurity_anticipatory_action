library(sf)
library(terra)
library(exactextractr)
library(dplyr)
library(stringr)

# -------- Join fews monthly timeseries with admin 2 units -----------
# --------------------------------------------------------------------

# Load data
fews <- st_read("data/intermediate/fews_all_long_ts.gpkg", quiet = TRUE)
admin <- st_read("data/som_admin2.geojson", quiet = TRUE) %>%
  select(adm2_name, adm2_pcode, geometry)

# Format date column for naming
fews$month <- format(fews$month, "%Y-%m-%d")

# Convert to terra vector
fews_vect <- vect(fews)

# Unique month/scenario groups for rasterization
months_all <- unique(fews_vect$month)
scenarios  <- unique(fews_vect$scenario)

fews_adm2_ts <- data.frame()

out_dir <- "data/intermediate/fews_monthly_rasters"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# ---------- Create Raster for each scenario for each month and perform zonal stats on adm 2 level ------------
for (m in months_all) {
  for (s in scenarios) {

    sub <- fews_vect[fews_vect$month == m & fews_vect$scenario == s, ]
    if (nrow(sub) == 0) next

    cat("Rasterizing:", s, m, "\n")

    # Rasterization
    r_template <- rast(sub, res = 0.01)
    r_phase <- rasterize(sub, r_template, field = "phase")
    #plot(r_phase, main = paste("Phase", s, m))

    # Save raster
    fname <- file.path(out_dir, paste0(s, "_", m, ".tif"))
    writeRaster(r_phase, fname, overwrite = TRUE)

    # Zonal stats for fews majority and mean value per adm2 unit
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

    fews_adm2_ts <- rbind(fews_adm2_ts, df)
  }
}


# ----------------------------------------------------------------------
# -------- Join fews phase on period level with admin 2 units ----------
# ----------------------------------------------------------------------

# Load data
fews_p <- st_read("data/intermediate/fews_all_long.gpkg", quiet = TRUE)
admin <- st_read("data/som_admin2.geojson", quiet = TRUE) %>%
  select(adm2_name, adm2_pcode, geometry)

# Output folder
out_dir <- "data/intermediate/fews_period_rasters"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# Convert to full date format
#fews_p$start <- as.Date(lubridate::my(fews_p$start))
#fews_p$end   <- as.Date(lubridate::my(fews_p$end))

# Group for disting scenario period combination
groups <- fews_p %>%
  st_drop_geometry() %>%
  distinct(scenario, start, end)

fews_adm2_period <- data.frame()


# ---------- Create rasters for each periods and perform zonal stats on adm 2 level ------------

for (i in seq_len(nrow(groups))) {

  # Select scenario and period start end for iteration
  s  <- groups$scenario[i]
  st <- groups$start[i]
  en <- groups$end[i]

  sub <- fews_p[
    fews_p$scenario == s &
      fews_p$start == st &
      fews_p$end == en, ]

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

  fews_adm2_period <- rbind(fews_adm2_period, df)
}

# Write monthly and period file
dir.create("data/outputs", showWarnings = FALSE, recursive = TRUE)

write.csv(fews_adm2_period, "data/outputs/fews_adm2_period.csv", row.names = FALSE)
write.csv(fews_adm2_ts, "data/outputs/fews_adm2_ts.csv", row.names = FALSE)


