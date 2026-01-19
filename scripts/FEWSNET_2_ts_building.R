library(sf)
library(dplyr)
library(tidyr)
library(lubridate)
library(purrr)



# Load fews file with all analyses
fews_all <- st_read("data/intermediate/fewsnet_all_geom.gpkg", quiet = TRUE)

fews_all <- fews_all %>%
  select(
    FNID,
    ADMIN2,
    scenario,
    start = projection_start,
    end   = projection_end,
    phase = value,
    geom
  )

# remove all rows with start date before 2017
fews_all <- fews_all[fews_all$start >= as.Date("2017-01-01"), ]

# write file
st_write(fews_all, "data/intermediate/fews_all_long.gpkg", delete_dsn = TRUE)



# --------- Build monthly time series ----------
# ----------------------------------------------

# Parse dates and build month sequence
fews_all_long <- fews_all %>%
  # add month column with all months contained in period
  mutate(
    month = map2(start, end, ~{
      if (is.na(.x) || is.na(.y) || .y < .x) return(as.Date(character()))
      s <- floor_date(.x, "month")
      e <- floor_date(.y, "month")
      seq(s, e, by = "month")
    })
  )

# Keep needed cols and expand months
fews_all_long_ts <- fews_all_long %>%
  select(FNID, ADMIN2, scenario, phase, month, geom) %>%
  unnest(month)

# write file
st_write(fews_all_long_ts, "data/intermediate/fews_all_long_ts.gpkg", delete_dsn = TRUE)

