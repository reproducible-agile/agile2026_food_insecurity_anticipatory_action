library(sf)
library(dplyr)

# --------- Create dataframe out of IPC API requests ----------
# -------------------------------------------------------------

# --------- For current ---------
ipc_folder <- "data/IPC_current_API"

# Read files
files <- list.files(ipc_folder, pattern = "\\.geojson$", full.names = TRUE)
ipc_list <- lapply(files, st_read, quiet = TRUE)

# Select relevant columns
cols <- c("area_id", "ipc_period", "overall_phase", "analysis_id",
          "area_name", "title", "start_current", "end_current", "geometry")
ipc_sel <- lapply(ipc_list, \(x) dplyr::select(x, any_of(cols)))

# Check if all files share the same columns
all_same <- all(sapply(ipc_sel, \(x) all(cols %in% names(x))))

# If yes, combine into one dataframe
if (all_same) {
  ipc_all_c <- dplyr::bind_rows(ipc_sel)
} else {
  cat("Not all files share the same columns.\n")
}


# --------- For projection 1 ---------
# Read files
ipc_folder <- "data/IPC_p1_API"

files <- list.files(ipc_folder, pattern = "\\.geojson$", full.names = TRUE)
ipc_list <- lapply(files, st_read, quiet = TRUE)

# Select relevant columns
cols <- c("area_id", "ipc_period", "overall_phase", "analysis_id",
          "area_name", "title", "start_proj", "end_proj", "geometry")
ipc_sel <- lapply(ipc_list, \(x) dplyr::select(x, any_of(cols)))

# Check if all files share the same columns
all_same <- all(sapply(ipc_sel, \(x) all(cols %in% names(x))))

# If yes, combine into one dataframe
if (all_same) {
  ipc_all_p1 <- dplyr::bind_rows(ipc_sel)
} else {
  cat("Not all files share the same columns.\n")
}


# --------- Join current and projection 1 ---------
# -------------------------------------------------

ipc_all_api <- ipc_all_c %>%
  left_join(
    ipc_all_p1 %>%
      st_drop_geometry() %>%
      rename(overall_phase_p1 = overall_phase) %>%
      select(area_id, start_proj, end_proj, overall_phase_p1),
    by = "area_id"
  )



# --------- Merge API data with website downloads ---------
# ---------------------------------------------------------


ipc_folder <- "data/IPC_website_dl"

# Read files
files <- list.files(ipc_folder, pattern = "\\.json$", full.names = TRUE)
ipc_list <- lapply(files, st_read, quiet = TRUE)

# Select desired columns
cols <- c("aar_id", "title","anl_id","current_from_date","current_thru_date","projected_from_date","projected_thru_date","overall_phase_P","overall_phase_C", "area")

# Check if all files share selected cols
check_list <- lapply(ipc_list, function(x) cols %in% names(x))
if (all(sapply(check_list, all))) {
  cat("All files share the selected cols")
} else {
  cat("Some not matching cols")
}



# --------- Create one dataframe from website downloads ---------
ipc_all_dl <- ipc_list %>%
  lapply(function(x) dplyr::select(x, any_of(cols))) %>%
  bind_rows()

# Convert date format
fmt <- "%d %b %Y"

ipc_all_dl$current_from_date  <- format(as.Date(paste0("01 ", ipc_all_dl$current_from_date), fmt), "%m.%Y")
ipc_all_dl$current_thru_date  <- format(as.Date(paste0("01 ", ipc_all_dl$current_thru_date), fmt), "%m.%Y")
ipc_all_dl$projected_from_date <- format(as.Date(paste0("01 ", ipc_all_dl$projected_from_date), fmt), "%m.%Y")
ipc_all_dl$projected_thru_date <- format(as.Date(paste0("01 ", ipc_all_dl$projected_thru_date), fmt), "%m.%Y")


# Rename relevant cols to match API based dataframe
rename_map <- c(
  area_id          = "aar_id",
  analysis_id      = "anl_id",
  area_name        = "area",
  start_current    = "current_from_date",
  end_current      = "current_thru_date",
  start_proj       = "projected_from_date",
  end_proj         = "projected_thru_date",
  overall_phase_p1 = "overall_phase_P",
  overall_phase    = "overall_phase_C"
)

# Cols to keep
keep_cols <- c("area_id","analysis_id","area_name",
               "start_current","end_current","start_proj","end_proj",
               "overall_phase_p1","overall_phase","title","geometry")


ipc_all_dl <- ipc_all_dl %>% # Renaming
  rename(!!!rename_map)

ipc_all_dl <- ipc_all_dl %>% select(any_of(keep_cols))
ipc_all_api    <- ipc_all_api %>% select(any_of(keep_cols))

# Merge
ipc_all <- bind_rows(ipc_all_api, ipc_all_dl)

# Drop point and multipoint eometries not relevant for the analysis
ipc_all <- ipc_all[!st_geometry_type(ipc_all) %in% c("POINT", "MULTIPOINT"), ]

# write file
dir.create("data/intermediate", showWarnings = FALSE, recursive = TRUE)

st_write(ipc_all, "data/intermediate/ipc_cs_p1_all.gpkg", delete_dsn = TRUE)





