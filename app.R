library(shiny)
library(dplyr)
library(yaml)
library(httr)
library(jsonlite)
library(openssl)
library(bslib)
library(googlesheets4)
library(sass)

# --- Source helper functions and modules ---
source("R/auth_helpers.R")     # used in server_main.R
source("R/gsheets_logger.R")   # used in app.R and server_main.R
source("R/ui_panels.R")      # used in server_main.R an ui_main.R
source("R/ui_main.R")          # uses spotify_playlists, atc_streams
source("R/server_main.R")      # uses config and helpers above

# --- Load config and globals ---
config <- yaml::read_yaml("resources/config.yml")
client_id <- config[["Spotify client ID"]]
redirect_uri <- config[["Redirect URI"]]
spotify_playlists <- config[["Spotify playlists"]]
atc_streams <- config[["ATC streams"]]
sheet_id <- init_gsheets_logger(config)

# --- Create theme ---
theme_config <- yaml::read_yaml(config[["Theme file path"]])
colors <- theme_config[["color"]]$palette
chill_atc_theme <- bs_theme(brand = config[["Theme file path"]])

# --- Launch app ---
shinyApp(
  ui = ui_main(spotify_playlists, atc_streams, theme = chill_atc_theme),
  server = server_main(config, spotify_playlists, atc_streams, sheet_id, client_id, redirect_uri)
)
