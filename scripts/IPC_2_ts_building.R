library(sf)
library(dplyr)
library(tidyr)
library(lubridate)
library(purrr)


# Load IPC file with all analyses
ipc_all <- st_read("data/intermediate/ipc_cs_p1_all.gpkg", quiet = TRUE)

# --------- Clean district names ----------
ipc_all$area_name <- gsub("\\s*\\(\\d+\\)", "", ipc_all$area_name)  # remove (1), (2), etc.
ipc_all$area_name <- trimws(ipc_all$area_name)                      # remove extra spaces
ipc_all$area_name <- tolower(ipc_all$area_name)                     # make lowercase

ipc_all$area_name[ipc_all$area_name == "jariiban 2"] <- "jariiban"



# --------- Prepare for pivoting to long table ----------
# Keep needed columns
ipc_all <- ipc_all %>%
 #st_drop_geometry() %>%
 select(analysis_id, area_id, area_name, start_current, end_current,
        overall_phase, start_proj, end_proj, overall_phase_p1)


# Rename to get a clean pattern for pivoting
ipc_all <- ipc_all %>%
  rename(
    phase_current = overall_phase,
    phase_proj    = overall_phase_p1
  )

# --------- Pivot to long table ----------

ipc_all_long <- ipc_all %>%
  pivot_longer(
    cols = c(start_current, end_current, phase_current,
             start_proj,   end_proj,   phase_proj),
    names_to = c(".value", "scenario"),
    names_pattern = "(start|end|phase)_(current|proj)"
  )

# write file
st_write(ipc_all_long, "data/intermediate/IPC_all_long.gpkg", delete_dsn = TRUE)

# --------- Build monthly time series ----------
# ----------------------------------------------


# Parse dates and build month sequence
ipc_all_long <- ipc_all_long %>%
  mutate(
    start = as.Date(paste0("01.", trimws(start)), "%d.%m.%Y"),
    end   = as.Date(paste0("01.", trimws(end)),   "%d.%m.%Y")
  ) %>%
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
ipc_all_long_ts <- ipc_all_long %>%
  select(analysis_id, area_id, area_name, scenario, phase, month, geom) %>%
  unnest(month)

# write file
st_write(ipc_all_long_ts, "data/intermediate/IPC_all_long_ts.gpkg", delete_dsn = TRUE)







