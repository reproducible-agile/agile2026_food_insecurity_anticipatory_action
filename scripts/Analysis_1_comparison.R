library(dplyr)
library(readr)
library(sf)
library(ggplot2)
library(viridis)
library(ggpubr)


# ---------------- Setup timeseries for visualization ----------------------------
# --------------------------------------------------------------------------------

# load input data
ipc_ts <- read_csv("data/outputs/ipc_adm2_ts.csv")
fews_ts <- read_csv("data/outputs/fews_adm2_ts.csv")
admin <- st_read("data/som_admin2.geojson", quiet = TRUE)

# Create figure folder
dir.create("figs", showWarnings = FALSE, recursive = TRUE)
dir.create("figs/map_files", showWarnings = FALSE, recursive = TRUE)

# Cut ts to shared period
start_month <- max(min(fews_ts$month), min(ipc_ts$month))
end_month   <- min(max(fews_ts$month), max(ipc_ts$month))

fews_ts  <- fews_ts  %>% filter(month >= start_month, month <= end_month)
ipc_ts   <- ipc_ts   %>% filter(month >= start_month, month <= end_month)


# Create joint long table
fews_ipc_ts_long <- bind_rows(
  fews_ts %>%
    filter(scenario %in% c("CS", "ML2")) %>%
    mutate(source = "FEWS NET") %>%
    select(adm2_name, adm2_pcode, month, source, scenario, phase_mean),
  
  ipc_ts %>%
    filter(scenario %in% c("current", "proj")) %>%
    mutate(source = "IPC") %>%
    select(adm2_name, adm2_pcode, month, source, scenario, phase_mean)
)


# ------------------ Plot current and projection timeline ------------------
# --------------------------------------------------------------------------

# ---------------------- Define plot function ----------------------
make_phase_plot <- function(df, scen_map, title, show_legend = TRUE) {
  
  dat <- df %>%
    filter(scenario %in% names(scen_map)) %>%
    mutate(
      scen_type = recode(scenario, !!!scen_map),
      scen_type = factor(scen_type, levels = c("FEWS NET", "IPC"))
    )
  
  # Monthly means
  monthly <- dat %>%
    group_by(month, scen_type) %>%
    summarise(mean_phase = mean(phase_mean, na.rm = TRUE), .groups = "drop") %>%
    mutate(legend = paste0("Monthly mean – ", scen_type))
  
  # Overall means 
  overall <- dat %>%
    group_by(scen_type) %>%
    summarise(mean_phase = mean(phase_mean, na.rm = TRUE), .groups = "drop") %>%
    mutate(legend = paste0("Overall mean – ", scen_type))
  
  # Legend configuration
  legend_levels <- c(
    "Monthly mean – FEWS NET",
    "Overall mean – FEWS NET",
    "Monthly mean – IPC",
    "Overall mean – IPC"
  )
  
  monthly$legend <- factor(monthly$legend, levels = legend_levels)
  overall$legend <- factor(overall$legend, levels = legend_levels)
  
  cols <- c(
    "Monthly mean – FEWS NET" = "#1F77B4",
    "Overall mean – FEWS NET" = "#AEC7E8",
    "Monthly mean – IPC"      = "#D95F02",
    "Overall mean – IPC"      = "#FDB863"
  )
  
  ltys <- c(
    "Monthly mean – FEWS NET" = "solid",
    "Monthly mean – IPC"      = "solid",
    "Overall mean – FEWS NET" = "dashed",
    "Overall mean – IPC"      = "dashed"
  )
  
  # Plot configuration
  p <- ggplot(monthly, aes(month, mean_phase, color = legend, linetype = legend)) +
    geom_line(linewidth = 0.8) +
    geom_hline(
      data = overall,
      aes(yintercept = mean_phase, color = legend, linetype = legend),
      linewidth = 0.8
    ) +
    scale_color_manual(values = cols, drop = FALSE) +
    scale_linetype_manual(values = ltys, drop = FALSE) +
    scale_y_continuous(breaks = seq(1.5, 4, 0.5)) +
    coord_cartesian(ylim = c(1.5, 4)) +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
    labs(x = "Year", y = "Mean food insecurity class", title = title) +
    guides(
      color = guide_legend(title = NULL),
      linetype = guide_legend(title = NULL)
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.text = element_text(size = 11),
      legend.position = if (show_legend) "bottom" else "none"
    )
  
  p
}

# ------------------------- Build the two plots ------------------------------
p1 <- make_phase_plot(
  fews_ipc_ts_long,
  scen_map = c(CS = "FEWS NET", current = "IPC"),
  title = "Current Assessments",
  show_legend = FALSE
) +
  theme(plot.title = element_text(size = 13))

p2 <- make_phase_plot(
  fews_ipc_ts_long,
  scen_map = c(ML2 = "FEWS NET", proj = "IPC"),
  title = "Projections",
  show_legend = FALSE
) +
  theme(plot.title = element_text(size = 13))

# Arrange with one common legend
fig <- ggarrange(
  p1, p2,
  ncol = 2, nrow = 1,
  common.legend = TRUE,
  legend = "bottom"
)

print(fig)

# Save plot as png
ggsave(
  "figs/Timeline_mean_phase.png",
  plot = fig,
  width = 12, height = 4.5, units = "in", dpi = 300
)



# ------------------- Maps of projection mean ---------------------------
# -----------------------------------------------------------------------

# mean phase per district & scenario over full ts
means_by_scen <- fews_ipc_ts_long %>%
  group_by(adm2_name, adm2_pcode, scenario) %>%
  summarise(mean_phase = mean(phase_mean, na.rm = TRUE), .groups = "drop")

# split out IPC proj and FEWS ML2
ipc_proj_mean  <- means_by_scen %>% filter(scenario == "proj")
fews_ml2_mean  <- means_by_scen %>% filter(scenario == "ML2")

# join with admin geometries
admin_ipc_proj  <- admin %>% left_join(ipc_proj_mean,  by = "adm2_pcode")
admin_fews_ml2  <- admin %>% left_join(fews_ml2_mean,  by = "adm2_pcode")

# Create overview maps
p_ipc_proj_mean <- ggplot(admin_ipc_proj) +
  geom_sf(aes(fill = mean_phase)) +
  scale_fill_viridis_c(option = "viridis", na.value = "grey90") +
  labs(title = "IPC Projection – Mean Phase", fill = "Mean phase") +
  theme_minimal()

p_fews_ml2_mean <- ggplot(admin_fews_ml2) +
  geom_sf(aes(fill = mean_phase)) +
  scale_fill_viridis_c(option = "viridis", na.value = "grey90") +
  labs(title = "FEWS NET Projection – Mean Phase", fill = "Mean phase") +
  theme_minimal()

print(p_ipc_proj_mean)
print(p_fews_ml2_mean)


# save as .gpkg for visualisation in QGIS
st_write(
  admin_ipc_proj,
  "figs/map_files/ipc_mean_proj.gpkg",
  delete_dsn = TRUE
)

st_write(
  admin_fews_ml2,
  "figs/map_files/fews_mean_proj.gpkg",
  delete_dsn = TRUE
)


# --------------- Maps of months in Emergency/Famine ---------------
# ------------------------------------------------------------------

# keep only FES NET ML2 IPC projection
fews_ml2 <- fews_ts %>%
  filter(scenario == "ML2")

ipc_proj <- ipc_ts %>%
  filter(scenario == "proj")

# keep only rows with class 4 or 5
fews_stats <- fews_ml2 %>%
  group_by(adm2_name, adm2_pcode) %>%
  summarise(
    total_months = n(),
    pct_4plus = mean(phase_majority >= 4, na.rm = TRUE) * 100,
    .groups = "drop"
  )

ipc_stats <- ipc_proj %>%
  group_by(adm2_name, adm2_pcode) %>%
  summarise(
    total_months = n(),
    pct_4plus = mean(phase_majority >= 4, na.rm = TRUE) * 100,
    .groups = "drop"
  )

# join district geometries
admin_fews <- admin %>% left_join(fews_stats, by = "adm2_pcode")
admin_ipc  <- admin %>% left_join(ipc_stats,  by = "adm2_pcode")


# Create overview maps
p_fews_over3 <- ggplot(admin_fews) +
  geom_sf(aes(fill = pct_4plus)) +
  scale_fill_viridis_c(option = "inferno", na.value = "grey90") +
  labs(title = "FEWSNET ML2 – % in Emergency/Famine", fill = "% class 4/5") +
  theme_minimal()

p_ipc_over3 <- ggplot(admin_ipc) +
  geom_sf(aes(fill = pct_4plus)) +
  scale_fill_viridis_c(option = "inferno", na.value = "grey90") +
  labs(title = "IPC Proj – % in Emergency/Famine", fill = "% class 4/5") +
  theme_minimal()

print(p_fews_over3)
print(p_ipc_over3)


# save as .gpkg for visualisation
st_write(
  admin_fews,
  "figs/map_files/fews_proj_highclass.gpkg",
  layer = "fews_ml2_highclass",
  delete_dsn = TRUE
)

st_write(
  admin_ipc,
  "figs/map_files/ipc_proj_highclass.gpkg",
  layer = "ipc_proj_highclass",
  delete_dsn = TRUE
)



