# ------------------------------------------------------
# Master script to reproduce all analyses
# ------------------------------------------------------

install.packages(c("exactextractr","ggpubr","viridis"))

# Load required packages (assumes packages are installed;
# see README for installation instructions)
invisible(lapply(
  c("sf","readr","dplyr","tidyr","lubridate","purrr",
    "terra","exactextractr","stringr","ggpubr","viridis","mapview"),
  library,
  character.only = TRUE
))

# Create directories used to store figures, intermediate data, and outputs
dir.create("figs", showWarnings = FALSE, recursive = TRUE)
dir.create("data/intermediate", showWarnings = FALSE, recursive = TRUE)
dir.create("data/outputs", showWarnings = FALSE, recursive = TRUE)



# ------- Run preprocessing workflow ------------
# -----------------------------------------------
message("Starting preprocessing workflow")

# FEWS NET preprocessing
source("scripts/FEWSNET_1_geom_join.R")
source("scripts/FEWSNET_2_ts_building.R")
source("scripts/FEWSNET_3_adm2_join.R")

# IPC preprocessing
source("scripts/IPC_1_data_merging.R")
source("scripts/IPC_2_ts_building.R")
source("scripts/IPC_3_adm2_join.R")

# --------- Run analysis workflow ---------------
# -----------------------------------------------
message("Starting analysis workflow")

source("scripts/Analysis_1_comparison.R")
source("scripts/Analysis_2_skillassessment.R")


message("Workflow completed successfully")
