login_display <- function() {
  card(class = "card--secondary",

    # not logged in
    conditionalPanel(
      condition = "!output.is_logged_in",
      actionButton(
        "login", "log in",
        icon = icon("spotify", class = "icon-spotify"),
        class = "btn-spotify"
      )
    ),

    # logged in
    conditionalPanel(
      condition = "output.is_logged_in",
      div(
        class = "centered-row",
        icon = icon("spotify", class = "icon-spotify"),
        span("logged in as: ", class = "user-label"),
        textOutput("user_email")
      )
    )
  )
}


volume_slider <- function(inputId, icon = "volume_up", value = 0.8) {
  div(
    class = "volume-slider",
    span(class = "material-icons volume-icon", icon),
    sliderInput(inputId, label = NULL, min = 0, max = 1, value = value, step = 0.01, ticks = FALSE)
  )
}


music_controls <- function(spotify_playlists) {
  card(
    class = "card--secondary",
    div(
      class = "flex-tight",
      div(
        class = "centered-column",
        div(
          class = "centered-row",
          actionButton("btn_prev", span("fast_rewind", class = "material-icons"), class = "btn-icon"),
          uiOutput("play_pause_button"),
          actionButton("btn_next", span("fast_forward", class = "material-icons"), class = "btn-icon"),
          actionButton("spotify_restart", span("replay", class = "material-icons"), class = "btn-icon")
        ),

        volume_slider("spotify_volume")

      ),

      div(
        class = "centered-column selectize-wrapper",
        selectInput("playlist_choice", "choose a Spotify playlist:", choices = names(spotify_playlists))
      )
    )
  )
}

atc_panel <- function(atc_streams) {
    card(
      class = "card--secondary",
      div(
        class = "flex-tight",
        div(
          class = "centered-column selectize-wrapper",
          selectInput("atc_stream", "choose a ATC stream:", choices = names(atc_streams))
        ),
        div(
          class = "centered-column",
          div(
            tags$audio(
              id = "atc_audio", controls = NA, style = "width: 100%;",
              src = atc_streams[[1]], type = "audio/mpeg"
            ),
            volume_slider("atc_volume")
          )
      )
    )
    )
  }

now_playing_panel <- function(id) {
  ns <- NS(id)

  card(
    class = "card--secondary card-narrow",
    div(
      class = "flex-tight",
      col_widths = c(6, 6),

      # col1: Album image
      div(
        class = "album-art",  # matches .track-info .album-art in SCSS
        uiOutput(ns("track_image"))
      ),

      # col2: Track info
      div(
        class = "track-info centered-column",

        h3(class = "now-playing-text", "now playing:"),

        span(class = "track-title", textOutput(ns("track_name"), inline = TRUE)),
        span(class = "track-artist", textOutput(ns("track_artist"), inline = TRUE)),
        div(class = "track-timer", textOutput(ns("track_progress"), inline = TRUE))
      )
    )
  )
}

tracking_display <- function() {
  card(class = "card--secondary",
    div(
      class = "flex-tight",

      conditionalPanel(
        condition = "output.session_active",
        div(class = "centered-column",
          span(class = "metric-label", HTML("listening<br>since")),
          span(class = "metric-value", textOutput("session_start_time_seconds"))
        )
      ),

      div(class = "centered-column",
        span(class = "metric-label", HTML("current<br>session")),
        span(class = "metric-value", textOutput("session_duration_seconds"))
      ),

      conditionalPanel(
        condition = "output.is_logged_in",
        div(class = "centered-column",
          span(class = "metric-label", HTML("your<br>total")),
          span(class = "metric-value", textOutput("user_total_time_seconds"))
        )
      ),

      div(class = "centered-column",
        span(class = "metric-label", HTML("global<br>total")),
        span(class = "metric-value", textOutput("global_total_time_seconds"))
      )
    )
  )
}




nowPlayingServer <- function(id, state) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    prev_image <- reactiveVal(NULL)
    current_img <- reactiveVal(NULL)

    # Track name
    output$track_name <- renderText({
      req(state$current_track)
      state$current_track$name
    })

    # Artist name
    output$track_artist <- renderText({
      req(state$current_track)
      state$current_track$artist
    })

    # Progress (0:00 / 3:45)
    output$track_progress <- renderText({
      req(state$track_progress)
      format_time <- function(ms) {
        total_sec <- round(ms / 1000)
        sprintf("%d:%02d", total_sec %/% 60, total_sec %% 60)
      }
      pos <- state$track_progress$position %||% 0
      dur <- state$track_progress$duration %||% 1
      paste(format_time(pos), "/", format_time(dur))
    })

    # Only update the album image if it changes
    observeEvent(state$current_track, {
      info <- state$current_track
      req(info$image)

      if (!identical(info$image, prev_image())) {
        prev_image(info$image)
        current_img(tags$img(
          src = info$image,
          class = "album-art"
        ))
      }
    })

    output$track_image <- renderUI({
      req(current_img())
      current_img()
    })
  })
}
