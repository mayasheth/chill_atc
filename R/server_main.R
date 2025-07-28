# R/server_main.R

server_main <- function(config, spotify_playlists, atc_streams, sheet_id, client_id, redirect_uri) {
  function(input, output, session) {

    update_interval_sec <- config[["Update interval (min.)"]] * 60 * 1000

    # --- Global state ---
    state <- reactiveValues(
      token = NULL,
      user = NULL,
      playlist_uri = "spotify:playlist:5PMoeSrcXv4OrURJi48z9c",
      current_track = NULL,
      spotify_playing = reactiveVal(FALSE), 
      atc_playing = reactiveVal(FALSE),
      session_active = FALSE,
      session_id = NULL,
      update_timer = NULL,
      start_time = NULL,
      total_time = 0,
      user_total_time = NA,
      global_total_time = NA,
      device_id = NULL,
      playlist_position = NULL,
      track_progress = NULL
    )

     # --- Debounced play states ---
    spotify_playing_debounced <- debounce(reactive(state$spotify_playing()), millis = 500)
    atc_playing_debounced <- debounce(reactive(state$atc_playing()), millis = 500)

    # --- Sync from raw input to central state ---
    observeEvent(input$spotify_playing, {
      state$spotify_playing(input$spotify_playing)
    })

    observeEvent(input$atc_playing, {
      state$atc_playing(input$atc_playing)
    })

    # --- Modular servers ---
    spotifyServer("spotify", state, spotify_playlists, client_id, redirect_uri, spotify_playing_debounced)
    atcServer("atc", state, atc_streams, atc_playing_debounced)
    trackingServer("tracker", state, sheet_id, atc_streams, update_interval_sec)
  }
}
