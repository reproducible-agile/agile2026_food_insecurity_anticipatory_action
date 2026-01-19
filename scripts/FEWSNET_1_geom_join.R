library(sf)
library(readr)
library(dplyr)

# --- Setup --------------------------------------------------------
fewsnet_csv <- "data/somalia_fews_all.csv"
lz_2011     <- "data/FEWSNET_lhz/SO_2011_tjAQFko/SO_Admin2_LHZ_2011.3.shp"
lz_2009     <- "data/FEWSNET_lhz/SO_2009_Cwt9JU5/SO_Admin2_LHZ_2009.3.shp"
lz_2016     <- "data/FEWSNET_lhz/SO_Admin2_LHZ_2016/SO_Admin2_LHZ_2016.2.shp"

# --- 1) Load data -------------------------------------------------
fews <- read_csv(fewsnet_csv, show_col_types = FALSE)
lz09 <- st_read(lz_2009, quiet = TRUE)
lz11 <- st_read(lz_2011, quiet = TRUE)
lz16 <- st_read(lz_2016, quiet = TRUE)

# Keep only the columns needed for the final join/output + geometry
sel_cols <- c("FNID", "ADMIN1", "ADMIN2")

lz09_sel <- lz09 %>% select(any_of(sel_cols), geometry)
lz11_sel <- lz11 %>% select(any_of(sel_cols), geometry)
lz16_sel <- lz16 %>% select(any_of(sel_cols), geometry)

# Row-bind the layers; this preserves individual polygons (no dissolve/union)
lz_all <- bind_rows(
  lz09_sel %>% mutate(source_year = 2009),
  lz11_sel %>% mutate(source_year = 2011),
  lz16_sel %>% mutate(source_year = 2016)
) %>%
  # Create an uppercase key for safe, case-insensitive matching
  mutate(FNID_UP = toupper(FNID))


# Keep only rows whose fnid exists in any (merged) shapefile FNID
fews_filt <- fews%>%
  filter(fnid %in% lz_all$FNID)

cat("Kept rows:", nrow(fews_filt), " / Original rows:", nrow(fews), "\n")




# --- 4) Print unmatched FNIDs -------------------------------------

# Find all FEWS rows that do NOT have a matching FNID in the shapefile
unmatched_rows <- fews %>%
  filter(!(fnid %in% lz_all$FNID))

# Print results
if (nrow(unmatched_rows) > 0) {
  cat("\nUnmatched FNIDs (present in FEWS CSV but not in any shapefile):\n")
  print(unmatched_rows %>% select(fnid))  # print just fnid column for clarity
  cat("\nTotal unmatched rows:", nrow(unmatched_rows), "\n")
} else {
  cat("\nAll FEWS rows matched shapefile records.\n")
}



# --- 4) Join the matching CSV rows to the geometries --------------
fews_with_geom <- lz_all %>%
  select(FNID, ADMIN1, ADMIN2, geometry) %>%
  inner_join(fews_filt, by = c("FNID" = "fnid"))



# --- 5) Result ----------------------------------------------------
dir.create("data/intermediate", showWarnings = FALSE, recursive = TRUE)

sf::st_write(
  fews_with_geom,
  file.path("data", "intermediate", "fewsnet_all_geom.gpkg"),
  delete_dsn = TRUE
)



