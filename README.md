⚠️ *Under construction*

This repository is currently being finalized and prepared for reproducibility review.

---

# FEWS NET vs IPC – Somalia (2017–2025)

This repository contains the preprocessing and analysis code supporting the paper:

**Food Insecurity Projections for Anticipatory Action: A Comparative Spatiotemporal Analysis of FEWS NET and the IPC in Somalia**

The workflow harmonizes FEWS NET and IPC acute food insecurity classifications,
generates comparable time series, aggregates results to admin 2 districts,
and performs both descriptive comparison and projection skill assessment.

---

## Usage

To reproduce all analyses:

1. Open the R project file  
   `agile2026_food_insecurity_anticipatory_action.Rproj`
   (R ≥ *X.X.X* required).

2. Open the script  
   `scripts/Master_script.R`.

3. Run the master script.  
   This will:
   - load all required libraries,
   - run the full preprocessing pipeline for FEWS NET and IPC data,
   - execute all comparative analyses and skill assessment,
   - generate all figures, maps, and output files necessary to reproduce results.

All outputs are written to the `figs/` and `data/outputs/` directories, that are created in the master script.

---

## Repository structure

```
.
├── agile2026_food_insecurity_anticipatory_action.Rproj
├── README.md
├── data/
│   ├── FEWSNET_lhz/            # FEWS NET livelihood zones
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
└── figs/                      # Generated figures
```



---

## Script overview

### Preprocessing

**FEWS NET**
- `FEWSNET_1_geom_join.R`  
  Prepares FEWS NET data and links classifications to spatial reference units.
- `FEWSNET_2_ts_building.R`  
  Generates time series on monthly and assessment period level.
- `FEWSNET_3_adm2_join.R`  
  Aggregates FEWS NET time series to admin-2 districts.

**IPC**
- `IPC_1_data_merging.R`  
  Merges IPC current and projection datasets.
- `IPC_2_ts_building.R`  
  Generates time series on monthly and assessment period level.
- `IPC_3_adm2_join.R`  
  Aggregates IPC time series to admin-2 districts.

### Analysis

- `Analysis_1_comparison.R`  
  Comparative analysis of FEWS NET and IPC current assessments and projections over the period 2017-2025.
- `Analysis_2_skillassessment.R`  
  Projection skill assessment, including bias metrics and error timelines.







