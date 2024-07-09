
# ds-pak-flood-contingency

<!-- badges: start -->
<!-- badges: end -->

This repo contains the analysis and monitoring of rainfall in selected basins
within Pakistan's lower Indus river basin.


The repo is structured as follows;

1. `data-raw/`: Contains R-code to create any data files needed for either the 
analysis pipeline or the monitoring pipeline whose sourcing is not already
self contained.
2. `_targets.R`: Contains a standard [{targets}](https://books.ropensci.org/targets/) pipeline to run the historical
analysis of rainfall and create the thresholds used for monitoring.
    a. To run the analysis you simply have to run `targets::tar_make()`. More details on targets can be found in the link above.
3. `src/` contains the monitoring pipeline used by the GH Actions. The final
step of the src/ process is to render and email `email_pak_monitor.Rmd`

Exploratory analysis performed to inform the final analyses can be found in the
`exploration` folder. The exploratory technical document rendered from exploration/01_map_aoi.qmd can be viewed [here](https://rpubs.com/zackarno/1199575)
