# Comparative Analysis of FEWS NET and IPC food insecurity data in Somalia

This repository contains the preprocessing and analysis code supporting the paper:

**Food Insecurity Projections for Anticipatory Action: A Comparative Spatiotemporal Analysis of FEWS NET and the IPC in Somalia**

The workflow harmonizes FEWS NET and IPC acute food insecurity classifications, generates comparable time series, aggregates results to admin-2 districts, and performs both descriptive comparison and projection skill assessment.

---

## Repository structure

```text
.
├── agile2026_food_insecurity_anticipatory_action.Rproj
├── README.md
├── data/
│   ├── FEWSNET_lhz/           # FEWS NET livelihood zones
│   ├── IPC_current_API/       # IPC current assessment data
│   ├── IPC_p1_API/            # IPC projection data
│   ├── IPC_website_dl/        # IPC website downloads
│   ├── som_admin2.geojson     # Somalia admin-2 boundaries
│   ├── somalia_fews_all.csv   # FEWS NET data
│   ├── intermediate/          # Intermediate processing outputs
│   └── outputs/               # Final processed datasets
│
├── scripts/
│   ├── Master_script.R
│   ├── FEWSNET_1_geom_join.R
│   ├── FEWSNET_2_ts_building.R
│   ├── FEWSNET_3_adm2_join.R
│   ├── IPC_1_data_merging.R
│   ├── IPC_2_ts_building.R
│   ├── IPC_3_adm2_join.R
│   ├── Analysis_1_comparison.R
│   └── Analysis_2_skillassessment.R
│
├── figs/                      # Generated figures
└── QGIS/                      # QGIS project file
```

---

## Usage

There are two options to reproduce the analysis workflow:

- **Docker workflow** (recommended, especially for Ubuntu users)
- **Native R setup**

---

### Option 1: With Docker (recommended)

This option provides a fully reproducible environment and is especially recommended for Ubuntu users.

#### Requirements

- Docker
- Docker Compose

#### Steps

1. Open a terminal and navigate to the repository folder.

2. Start the rocker service:

```bash
RUID="$(id -u)" docker-compose up
```

3. Open your browser and visit:

```text
http://localhost:8887
```

This opens the RStudio interface running inside Docker (needed for map display).

4. In RStudio, open the R project file:

```text
agile2026_food_insecurity_anticipatory_action.Rproj
```

5. Navigate to:

```text
scripts/Master_script.R
```

6. Run `Master_script.R`.

This will:

- load all required libraries,
- run the full preprocessing pipeline for FEWS NET and IPC data,
- execute all comparative analyses and skill assessment,
- generate all figures, maps, and output files necessary to reproduce results.

All outputs are written to the `figs/` and `data/outputs/` directories, which are created automatically in the master script.

Visualization styles used for the output map files shown in the paper are stored in the QGIS project under `QGIS/`.

---

### Option 2: Native R setup

1. Open the R project file:

```text
agile2026_food_insecurity_anticipatory_action.Rproj
```

(R version ≥ 4.2.0 is required.)

2. Open the script:

```text
scripts/Master_script.R
```

3. Run the master script.

This will:

- load all required libraries,
- run the full preprocessing pipeline for FEWS NET and IPC data,
- execute all comparative analyses and skill assessment,
- generate all figures, maps, and output files necessary to reproduce results.

All outputs are written to the `figs/` and `data/outputs/` directories, which are created automatically in the master script.

Visualization styles used for the output map files shown in the paper are stored in the QGIS project under `QGIS/`.

---

## Script overview

### Preprocessing

#### FEWS NET

- `FEWSNET_1_geom_join.R`  
  Prepares FEWS NET data and links classifications to spatial reference units.

- `FEWSNET_2_ts_building.R`  
  Generates time series on monthly and assessment period level.

- `FEWSNET_3_adm2_join.R`  
  Aggregates FEWS NET time series to admin-2 districts.

#### IPC

- `IPC_1_data_merging.R`  
  Merges IPC current and projection datasets.

- `IPC_2_ts_building.R`  
  Generates time series on monthly and assessment period level.

- `IPC_3_adm2_join.R`  
  Aggregates IPC time series to admin-2 districts.

### Analysis

- `Analysis_1_comparison.R`  
  Comparative analysis of FEWS NET and IPC current assessments and projections over the period 2017–2025.

- `Analysis_2_skillassessment.R`  
  Projection skill assessment, including bias metrics and error timelines.



