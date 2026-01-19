library(dplyr)
library(lubridate)
library(readr)
library(sf)
library(mapview)
library(ggplot2)
library(tidyr)
library(ggpubr)


# ---------------------------------------------------------
# --------- Generate skill assessment dataframes ----------
# ---------------------------------------------------------

# load data
fews_adm2_p <- read_csv("data/outputs/fews_adm2_period.csv")
ipc_adm2_p <- read_csv("data/outputs/ipc_adm2_period.csv")
ipc_adm2_p <- ipc_adm2_p %>%
  mutate( end = floor_date(end, "month") + days_in_month(end) - 1 )

admin <- st_read("data/som_admin2.geojson", quiet = TRUE) %>%
  select(adm2_pcode, adm2_name)

# -------------- Generate FEWS NET pairs df -----------------

ML2 <- fews_adm2_p %>% filter(scenario == "ML2")
CS <- fews_adm2_p %>% filter(scenario == "CS")

fews_pairs <- ML2 %>%
  inner_join(CS,
             by = c("adm2_pcode", "adm2_name"),
             suffix = c("_ML2", "_CS")) %>%

  # select overlapping projection and current periods
  mutate(overlap = (start_ML2 <= end_CS & end_ML2   >= start_CS)) %>%
  filter(overlap) %>%

  # calculate skill assessment metrics
mutate(
  diff = phase_majority_ML2 - phase_majority_CS, 
  mean_diff = phase_mean_ML2 - phase_mean_CS,
  hit  = (phase_majority_ML2 == phase_majority_CS),
  bias = case_when(
    diff > 0 ~ "positive",  
    diff < 0 ~ "negative",  
    TRUE     ~ "none"
  )

)

# -------------- Generate IPC pairs df -----------------

proj <- ipc_adm2_p %>% filter(scenario == "proj")
curr <- ipc_adm2_p %>% filter(scenario == "current")

ipc_pairs <- proj %>%
  inner_join(curr,
             by = c("adm2_pcode", "adm2_name"),
             suffix = c("_proj", "_curr")) %>%

  # select directly adjacent projection and current periods
  mutate(adjacent = (start_curr == end_proj + days(1))) %>%
  filter(adjacent) %>%

# calculate skill assessment metrics
mutate(
  diff = phase_majority_proj - phase_majority_curr,
  mean_diff = phase_mean_proj - phase_mean_curr,
  hit  = (phase_majority_proj == phase_majority_curr),
  bias = case_when(
    diff > 0 ~ "positive",   
    diff < 0 ~ "negative",  
    TRUE     ~ "none"
  )

)

options(scipen = 999)


# ------- Calculate mean difference between mean and majority values for every scenario -------
fews_majority_vs_mean <- fews_pairs %>%
  summarise(
    n = n(),
    
    ml2_mean_abs_dev = mean(abs(phase_majority_ML2 - phase_mean_ML2), na.rm = TRUE),
    cs_mean_abs_dev  = mean(abs(phase_majority_CS - phase_mean_CS), na.rm = TRUE)
  )

ipc_majority_vs_mean <- ipc_pairs %>%
  summarise(
    n = n(),
    
    proj_mean_abs_dev = mean(abs(phase_majority_proj - phase_mean_proj), na.rm = TRUE),
    curr_mean_abs_dev = mean(abs(phase_majority_curr - phase_mean_curr), na.rm = TRUE)
  )

# ------- Calculate overview metrics for skillassessment ------------
# -------------------------------------------------------------------

fews_metrics <- fews_pairs %>%
  summarise(
    n_pairs  = n(),
    accuracy = mean(hit), # accuracy
    
    n_nonhit = sum(!hit),   # total number of non-hits
    
   # percentage positive and negative bias
    pct_pos_bias_all =
      sum(diff > 0) / n_pairs * 100,
    
    pct_neg_bias_all =
      sum(diff < 0) / n_pairs * 100,
    
    # percentage of non hits, that are off only 1 class
    pct_absdiff1_nonhit =
      sum(!hit & abs(diff) == 1) / n_nonhit * 100
  )

ipc_metrics <- ipc_pairs %>%
  summarise(
    n_pairs  = n(),
    accuracy = mean(hit),
    
    n_nonhit = sum(!hit),
    
    pct_pos_bias_all =
      sum(diff > 0) / n_pairs * 100,
    
    pct_neg_bias_all =
      sum(diff < 0) / n_pairs * 100,
    
    pct_absdiff1_nonhit =
      sum(!hit & abs(diff) == 1) / n_nonhit * 100
  )

bind_rows(
  FEWSNET = fews_metrics,
  IPC     = ipc_metrics,
  .id = "dataset"
)



# ----------------------------------------------------------
# ------- Visualization of skill assessment results --------
# ----------------------------------------------------------

# -------------- Generate bias matrices ----------------
# ------------------------------------------------------

# ------- Build bias matrix plot function -------

make_bias_matrix <- function(df, actual, predicted, title,
                             pred_levels, bias_levels, fill_limits,
                             show_legend = TRUE) {
  
  # Calculate bias and count occurrences per predicted class and bias
  cm <- df %>%
    transmute(
      pred = .data[[predicted]],
      bias = .data[[predicted]] - .data[[actual]]
    ) %>%
    count(bias, pred, name = "n") %>%
    
    complete(bias = bias_levels, pred = pred_levels, fill = list(n = 0)) %>%
    
    mutate(pct = n / sum(n) * 100)
  
  # Plot bias matrix as heatmap
  ggplot(cm, aes(pred, bias, fill = pct)) +
    geom_tile(color = "grey85") +
    
    geom_text(aes(label = ifelse(pct > 0, sprintf("%.1f%%", pct), "")), size = 3) +
    
    # Configurate axis
    scale_x_continuous(breaks = pred_levels) +
    scale_y_continuous(breaks = bias_levels) +
    scale_fill_gradient(
      low = "white", high = "steelblue",
      limits = fill_limits, oob = scales::squish
    ) +
    
    # Configurate labels and legend
    labs(
      title = title,
      x = "Predicted class",
      y = "Bias (predicted − actual)",
      fill = "%"
    ) +
    guides(
      fill = guide_colorbar(
        title = "Percent",
        title.position = "top",
        title.hjust = 0.5,
        barheight = unit(0.8, "cm"),
        barwidth  = unit(6, "cm")
      )
    ) +
    
    # Theme and legend colour
    theme_minimal(base_size = 10) +
    theme(
      plot.title = element_text(size = 11),
      legend.text = element_text(size = 10),
      legend.position = if (show_legend) "bottom" else "none"
    )
}

# Create shared grid and visualization scale for both matrices for comparability

# Define the full set of predicted classes
pred_levels_all <- sort(unique(c(
  fews_pairs$phase_majority_ML2,
  ipc_pairs$phase_majority_proj
)), na.last = NA)

# Define the full set of bias values used across both datasets
bias_levels_all <- sort(unique(c(
  fews_pairs$phase_majority_ML2 - fews_pairs$phase_majority_CS,
  ipc_pairs$phase_majority_proj - ipc_pairs$phase_majority_curr
)), na.last = NA)

# Define function to calculate the maximum cell percentage in a bias matrix for shared color scaling
max_cell_pct <- function(df, actual, predicted, pred_levels, bias_levels) {
  df %>%
   
    transmute(
      pred = .data[[predicted]],
      bias = .data[[predicted]] - .data[[actual]]
    ) %>%
   
    count(bias, pred, name = "n") %>%
    
    complete(bias = bias_levels, pred = pred_levels, fill = list(n = 0)) %>%
    
    mutate(pct = n / sum(n) * 100) %>%
    
    summarise(mx = max(pct, na.rm = TRUE)) %>%
    pull(mx)
}

# Define shared fill limits using defined function
fill_limits_shared <- c(0, max(
  max_cell_pct(fews_pairs, "phase_majority_CS",   "phase_majority_ML2",  pred_levels_all, bias_levels_all),
  max_cell_pct(ipc_pairs,  "phase_majority_curr", "phase_majority_proj", pred_levels_all, bias_levels_all)
))


# ---------- Generate bias matrix plots -------------------

p_fews <- make_bias_matrix(
  fews_pairs, "phase_majority_CS", "phase_majority_ML2",
  "FEWS Bias Matrix (%)",
  pred_levels_all, bias_levels_all, fill_limits_shared,
  show_legend = FALSE
)

p_ipc <- make_bias_matrix(
  ipc_pairs, "phase_majority_curr", "phase_majority_proj",
  "IPC Bias Matrix (%)",
  pred_levels_all, bias_levels_all, fill_limits_shared,
  show_legend = FALSE
)

# --------------- Arrange plots with one common legend ------------------

fig <- ggarrange(
  p_fews, p_ipc,
  ncol = 2, nrow = 1,
  common.legend = TRUE,
  legend = "bottom"
)

print(fig)

# Save plots as .png
ggsave(
  "figs/Bias_matrices.png",
  plot = fig,
  width = 12, height = 5, units = "in", dpi = 300
)




# -------------- Generate district level bias map ----------------
# ----------------------------------------------------------------

# Create dfs with bias summarized by district
fews_adm2_bias <- fews_pairs %>%
  group_by(adm2_pcode, adm2_name) %>%
  summarise(
    n = n(),
    mean_bias = mean(mean_diff, na.rm = TRUE),
    .groups = "drop"
  )

ipc_adm2_bias <- ipc_pairs %>%
  group_by(adm2_pcode, adm2_name) %>%
  summarise(
    n = n(),
    mean_bias = mean(mean_diff, na.rm = TRUE),
    .groups = "drop"
  )

# Join admin geometries
fews_adm2_sa_stats_sf <- admin %>%
  left_join(fews_adm2_bias, by = c("adm2_pcode", "adm2_name"))

ipc_adm2_sa_stats_sf <- admin %>%
  left_join(ipc_adm2_bias, by = c("adm2_pcode", "adm2_name"))

# Plot maps with same colour scale and breaks for comparison
bias_cols <- colorRampPalette(c("red3", "white", "steelblue"))(100)

breaks_7 <- seq(-0.5, 0.5, length.out = 8)

# Testview of maps
plot_bias_map <- function(sf_obj, title) {
  ggplot(sf_obj) +
    geom_sf(aes(fill = mean_bias)) +
    scale_fill_gradientn(
      colors = bias_cols,
      limits = range(breaks_7),
      breaks = breaks_7,
      oob = scales::squish
    ) +
    labs(title = title, fill = "Mean bias") +
    theme_minimal(base_size = 10)
}

p_fews_bias <- plot_bias_map(fews_adm2_sa_stats_sf, "FEWS NET – Mean Bias")
p_ipc_bias  <- plot_bias_map(ipc_adm2_sa_stats_sf,  "IPC – Mean Bias")

print(p_fews_bias)
print(p_ipc_bias)


# save files as .gpkg for visualization in QGIS
st_write(
  fews_adm2_sa_stats_sf,
  "figs/map_files/fews_mean_bias.gpkg",
  layer = "fews_mean_bias",
  delete_dsn = TRUE
)

st_write(
  ipc_adm2_sa_stats_sf,
  "figs/map_files/ipc_mean_bias.gpkg",
  layer = "ipc_mean_bias",
  delete_dsn = TRUE
)


# ------------ Create timeline of projection errors plot --------------
# ---------------------------------------------------------------------

# ------------ Create function for plotting timeline ------------
plot_error_timeline <- function(df, start_col, diff_col = "diff", title,
                                show_legend = FALSE) {
  
  # desired stacking order for bars (psotive and negative direction)
  stack_order <- c(-4, 4, -3, 3, -2, 2, -1, 1)
  
  # create error timeline df
  error_timeline <- df %>%
    filter(.data[[diff_col]] != 0) %>%
    group_by(.data[[start_col]], .data[[diff_col]]) %>%
    summarise(n = n(), .groups = "drop") %>%
    mutate(
      signed_n = ifelse(.data[[diff_col]] > 0, n, -n),
      diff_fac = factor(.data[[diff_col]], levels = stack_order)
    ) %>%
    arrange(.data[[start_col]], match(as.numeric(as.character(diff_fac)), stack_order))
  
  # colour palette
  diff_colors <- c(
    "-1" = "gold",   "1" = "gold",
    "-2" = "orange", "2" = "orange",
    "-3" = "red",    "3" = "red"
  )
  
  # plot configuration
  ggplot(error_timeline,
         aes(x = as.Date(.data[[start_col]]), y = signed_n, fill = diff_fac)) +
    geom_col() +
    geom_hline(yintercept = 0) +
    scale_fill_manual(values = diff_colors, drop = FALSE) +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
    labs(
      title = title,
      x = "Year",
      y = "Number of districts misclassified",
      fill = NULL
    ) +
    coord_cartesian(ylim = c(-40, 80)) +
  
    theme_minimal(base_size = 10) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      plot.title = element_text(size = 11),
      legend.text = element_text(size = 10),
      legend.position = if (show_legend) "bottom" else "none"
    )
}

# ------------------ Create plot plots ------------------
p_fews <- plot_error_timeline(
  fews_pairs,
  start_col = "start_CS",
  diff_col  = "diff",
  title     = "Timeline of Projection Errors (FEWSNET)",
  show_legend = FALSE
)

p_ipc <- plot_error_timeline(
  ipc_pairs,
  start_col = "start_curr",
  diff_col  = "diff",
  title     = "Timeline of Projection Errors (IPC)",
  show_legend = FALSE
)

# ------------------ Add custom legend ------------------
legend_df <- data.frame(
  mag = factor(c("±1", "±2", "±3", "±4"), levels = c("±1","±2","±3","±4")),
  x = 1, y = 1
)

mag_cols <- c("±1"="gold", "±2"="orange", "±3"="red")

legend_plot <- ggplot(legend_df, aes(x, y, fill = mag)) +
  geom_tile() +
  scale_fill_manual(values = mag_cols, drop = FALSE) +
  guides(fill = guide_legend(
    title = "Bias magnitude",
    nrow = 1,
    override.aes = list(shape = 22, size = 8)
  )) +
  # >>> MATCHED TO BIAS MATRIX STYLE <<<
  theme_void(base_size = 10) +
  theme(
    legend.text  = element_text(size = 10),
    legend.title = element_text(size = 11),
    legend.position = "bottom"
  )

legend_grob <- get_legend(legend_plot)

# ------- Arrange into one figure + custom shared legend ----------
panels <- ggarrange(p_fews, p_ipc, ncol = 2, nrow = 1)

fig <- ggarrange(
  panels,
  legend_grob,
  ncol = 1,
  heights = c(1, 0.12)
)

print(fig)

# save to .png
ggsave(
  "figs/Error_timeline.png",
  plot = fig,
  width = 10, height = 4.5, units = "in", dpi = 300
)









