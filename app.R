library(shiny)
library(yaml)
library(httr)
library(jsonlite)
library(openssl)
library(bslib)
library(googlesheets4)

# --- Source helper functions ---
source("R/auth_helpers.R")     # used in server_main.R
source("R/gsheets_logger.R")   # used in app.R and server_main.R
source("R/now_playing.R")      # used in server_main.R

# --- Source UI and server modules ---
source("R/ui_main.R")          # uses spotify_playlists, atc_streams
source("R/server_main.R")      # uses config and helpers above
source("R/theme.R")            # aesthetics

# --- Load config and globals ---
config <- yaml::read_yaml("resources/config.yml")
client_id <- config[["Spotify client ID"]]
redirect_uri <- config[["Redirect URI"]]
spotify_playlists <- config[["Spotify playlists"]]
atc_streams <- config[["ATC streams"]]
sheet_id <- init_gsheets_logger(config)

# --- Launch app ---
shinyApp(
  ui = ui_main(spotify_playlists, atc_streams, theme = chill_atc_theme),
  server = server_main(config, spotify_playlists, atc_streams, sheet_id, client_id, redirect_uri)
)
