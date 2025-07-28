# --- Import packages ---
packages <- c(
 "shiny", "tibble", "dplyr", "purrr",  
 "yaml", "httr", "jsonlite", "openssl",
 "bslib", "googlesheets4", "sass"
)
suppressPackageStartupMessages(
  lapply(packages, library, character.only = TRUE)
)

# --- Source helper functions and modules ---
module_files <- list.files("R/modules", pattern = "\\.R$", full.names = TRUE)
source_files <- c(
  "R/utils.R",
  "R/ui_panels.R",
  "R/ui_main.R",
  module_files,
  "R/server_main.R"
)
purrr::walk(source_files, source)

# --- Load config and globals ---
config <- yaml::read_yaml("resources/config.yml")
client_id <- config[["Spotify client ID"]]
redirect_uri <- config[["Redirect URI"]]
spotify_playlists <- config[["Spotify playlists"]]
atc_streams <- config[["ATC streams"]]
sheet_id <- init_gsheets_logger_deployment(config)

# --- Create theme ---
theme_config <- yaml::read_yaml(config[["Theme file path"]])
chill_atc_theme <- bs_theme(brand = config[["Theme file path"]])

# --- Launch app ---
shinyApp(
  ui = ui_main(spotify_playlists, atc_streams, theme = chill_atc_theme),
  server = server_main(config, spotify_playlists, atc_streams, sheet_id, client_id, redirect_uri)
)
