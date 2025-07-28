# --- Login panel ---
login_display <- function(id) {
  ns <- NS(id)

  card(class = "card--secondary",

    # not logged in
    conditionalPanel(
      condition = sprintf("!output['%s']", ns("is_logged_in")),
      actionButton(
        ns("login"), "log in",
        icon = icon("spotify", class = "icon-spotify"),
        class = "btn-spotify"
      )
    ),

    # logged in
    conditionalPanel(
      condition = sprintf("output['%s']", ns("is_logged_in")),
      div(
        class = "centered-row",
        icon = icon("spotify", class = "icon-spotify"),
        span("logged in as: ", class = "user-label"),
        textOutput(ns("user_email"))
      )
    )
  )
}

# --- Volume slider utility ---
volume_slider <- function(inputId, icon = "volume_up", value = 0.8) {
  div(
    class = "volume-slider",
    span(class = "material-icons volume-icon", icon),
    sliderInput(inputId, label = NULL, min = 0, max = 1, value = value, step = 0.01, ticks = FALSE)
  )
}


# --- Spotify music controls ---
music_controls <- function(id, spotify_playlists) {
  ns <- NS(id)

  conditionalPanel(
    condition = sprintf("output['%s']", ns("is_logged_in")),
    card(
      class = "card--secondary",
      div(
        class = "flex-tight",
        div(
          class = "centered-column",
          div(
            class = "centered-row",
            actionButton(ns("btn_prev"), span("fast_rewind", class = "material-icons"), class = "btn-icon"),
            uiOutput(ns("spotify_play_button")),
            actionButton(ns("btn_next"), span("fast_forward", class = "material-icons"), class = "btn-icon"),
            actionButton(ns("spotify_restart"), span("replay", class = "material-icons"), class = "btn-icon")
          ),
          volume_slider(ns("spotify_volume"))
        ),

        div(
          class = "centered-column selectize-wrapper",
          selectInput(ns("playlist_choice"), "choose a Spotify playlist:", choices = names(spotify_playlists))
        )
      )
    )
  )
}

# --- Now playing panel ---
now_playing_panel <- function(id) {
  ns <- NS(id)
  
  conditionalPanel(
    condition = sprintf("output['%s']", ns("show_now_playing")),
    card(
      class = "card--secondary",
      div(
        class = "flex-tight",
        div(
          class = "album-art",
          uiOutput(ns("track_image"))
        ),
        div(
          class = "track-info centered-column",
          span(class = "now-playing-text", "now playing:"),
          span(class = "track-name", textOutput(ns("track_name"), inline = TRUE)),
          span(class = "track-artist", textOutput(ns("track_artist"), inline = TRUE)),
          div(class = "track-timer", textOutput(ns("track_progress"), inline = TRUE))
        )
      )
    )
  )
}

# --- ATC panel ---
atc_panel <- function(id, atc_streams) {
  ns <- NS(id)
  card(
    class = "card--secondary",
    div(
      class = "flex-tight",
      div(
        class = "centered-column selectize-wrapper",
        selectInput(ns("atc_stream"), "choose an ATC stream:", choices = names(atc_streams))
      ),
      div(
        class = "centered-column",
        div(
          tags$audio(id = "atc_audio", src = atc_streams[[1]], type = "audio/mpeg", style = "display:none;"),
          div(
            class = "centered-row",
            uiOutput(ns("atc_play_button")),
            uiOutput(ns("atc_stream_label"))
          ),
          volume_slider(ns("atc_volume"))
        )
      )
    )
  )
}

# --- Listening time tracking display ---
tracking_display <- function(id, spotify_ns) {
  ns <- NS(id)

  card(class = "card--secondary",
    div(
      class = "flex-tight",

      conditionalPanel(
        condition = sprintf("output['%s']", ns("session_active")),
        div(class = "centered-column",
          span(class = "metric-label", HTML("listening<br>since")),
          span(class = "metric-value", textOutput(ns("session_start_time_seconds")))
        )
      ),

      div(class = "centered-column",
        span(class = "metric-label", HTML("current<br>session")),
        span(class = "metric-value", textOutput(ns("session_duration_seconds")))
      ),

      conditionalPanel(
        condition = paste0("output['", spotify_ns, "-is_logged_in']"),
        div(class = "centered-column",
          span(class = "metric-label", HTML("your<br>total")),
          span(class = "metric-value", textOutput(ns("user_total_time_seconds")))
        )
      ),

      div(class = "centered-column",
        span(class = "metric-label", HTML("global<br>total")),
        span(class = "metric-value", textOutput(ns("global_total_time_seconds")))
      )
    )
  )
}
