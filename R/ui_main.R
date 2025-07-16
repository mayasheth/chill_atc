

login_display <- function() {
    div(
    conditionalPanel(
      condition = "!output.is_logged_in",
      div(
        class = "d-flex justify-content-center",
        actionButton(
          "login", "log in",
          icon = icon("spotify", class = "me-2"),
          style = "width: fit-content; display: inline-flex; align-items: center; justify-content: center; --bs-btn-color: var(--brand-spotify_green); --bs-btn-border-color: var(--brand-spotify_green); --bs-btn-hover-color: var(--brand-near_black); --bs-btn-hover-bg: var(--brand-spotify_green); --bs-btn-hover-border-color: var(--brand-spotify_green); --bs-btn-active-color: var(--brand-near_black); --bs-btn-active-bg: var(--brand-spotify_green); --bs-btn-active-border-color: var(--brand-spotify_green);"
        )
      )
    ),
    
    conditionalPanel(
      condition = "output.is_logged_in",
      div(
        class = "d-flex justify-content-center",
        uiOutput("user_display")
        )
    )
    
    )
}

volume_slider <- function(inputId, icon = "volume_up", value = 0.8) {
  div(
    class = "d-flex align-items-center gap-2 volume-slider",
    span(class = "material-icons", style = "font-size: 2rem; margin-top: 0.5rem;", icon),
    sliderInput(inputId, label = NULL, min = 0, max = 1, value = value, step = 0.01, ticks = FALSE)
  )
}

music_controls <- function(spotify_playlists) {
  div(
    class = "music-panel text-center",
    style = "width: 100%;",
    layout_columns(
      col_widths = c(6, 6),
      gap = "2rem",
      div(
        class = "d-flex align-items-center justify-content-center",
        div(
          class = "spotify-select w-100",
          style = "position: relative;",
          selectInput("playlist_choice", "choose a Spotify playlist:", choices = names(spotify_playlists))
        )
      ),
      div(
        class = "d-flex flex-column align-items-center justify-content-center h-100",
        div(
          class = "music-buttons d-flex gap-2 justify-content-center my-2",
          uiOutput("play_pause_button"),
          actionButton("btn_next", span("skip_next", class = "material-icons"), class = "btn-sm"),
          actionButton("spotify_restart", span("replay", class = "material-icons"), class = "btn-sm")
        ),
            volume_slider("spotify_volume")
        )
    )
  )
}



now_playing_panel <- function(id) {
  ns <- NS(id)
  div(
    class = "now-playing-panel",
    style = "max-width: 400px; width: 100%;",
    tags$h3(class = "text-center", "now playing..."),
    div(
      class = "d-flex flex-wrap justify-content-between align-items-center",
      style = "gap: 1rem;",
      div(uiOutput(ns("track_image"))),
      div(
        tags$p(HTML(paste0("<strong>track:</strong> ", textOutput(ns("track_name"), inline = TRUE)))),
        tags$p(HTML(paste0("<strong>artist:</strong> ", textOutput(ns("track_artist"), inline = TRUE))))
      )
    )
  )
}

ui_main <- function(spotify_playlists, atc_streams, theme) {
  page_fixed(
    theme = theme,
    tags$style(HTML(".container {max-width: 900px !important;}")),

    tags$style(HTML("
    .chill-card {
      max-width: 100%;
      background-color: var(--brand-near_black);
      color: var(--bs-foreground);
      display: inline-flex;
      align-items: center;
      justify-content: center;
      position: relative;
      overflow: visible;
    }
    
    .card-body {
      overflow: visible !important;
      position: relative; /* needed to contain absolutely-positioned children */
    }
    
    .btn-sm {
      padding: 4px 10px;
      line-height: 1.2;
    }
    .selectize-control.single .selectize-input {
      background-color: var(--brand-near_black);
      color: var(--brand-light_ocean);
      border: 1px solid var(--brand-light_ocean);
      overflow: visible !important;
    }
    .selectize-control.single .selectize-input.dropdown-active {
      border-bottom-left-radius: 0;
      border-bottom-right-radius: 0;
      overflow: visible !important;
    }
    
    .selectize-dropdown {
      position: absolute !important;
      z-index: 9999 !important;
      background-color: var(--brand-near_black);
      border: 1px solid var(--brand-light_ocean);
    }
    
    .selectize-dropdown-content {
      max-height: calc(2.5em * 5);
      overflow-y: auto;
    }
    
    .selectize-dropdown .selectize-dropdown-content .option {
      background-color: var(--brand-near_black);
      color: var(--brand-light_ocean);
    }
    
    .selectize-dropdown .selectize-dropdown-content .option.active {
      background-color: var(--brand-light_ocean);
      color: var(--brand-near_black);
    }
    .selectize-dropdown .selectize-dropdown-content .option.selected {
      background-color: var(--brand-pale_ocean);
      color: var(--bs-brand-near_black);
    }

    /* Slider thumb */
    .volume-slider .irs--shiny .irs-handle {
      background-color: var(--brand-light_ocean);
      border: 0.2rem solid var(--brand-light_ocean);
      width: 1.5rem;
      height: 1.5rem;
    }
    
    .volume-slider .irs--shiny .irs-handle.state_hover {
      background-color: var(--brand-pale_gray);
    }

    /* Outer unfilled track */
    .volume-slider .irs--shiny .irs-line {
      background-color: var(--brand-teal) !important;
      height: 0.3rem;
      border-radius: 4px;
    }

    /* Filled portion (active progress) */
    .volume-slider .irs--shiny .irs-bar {
      background-color: var(--brand-light_ocean) !important;
      height: 0.3rem;
      border-radius: 4px;
    }

    /* Hide numeric value (bubble above the slider knob) */
    .volume-slider .irs--shiny .irs-single {
      display: none !important;
    }

    /* Hide min and max (0 / 1) */
    .volume-slider .irs--shiny .irs-min,
    .volume-slider .irs--shiny .irs-max {
      display: none !important;
    }


    ")),

    tags$head(
      tags$script(src = "https://sdk.scdn.co/spotify-player.js"),
      tags$script(src = "spotify-atc.js"),
      tags$link(
        href = "https://fonts.googleapis.com/icon?family=Material+Icons",
        rel = "stylesheet"
      )
    ),

    tags$div(
      class = "text-center my-4",
      tags$h1("chill atc")
    ),

    # 🎵 Spotify Section
    card(
      class = "mb-4 w-100 chill-card",
      full_screen = FALSE,
      card_header(class = "text-center", h3("music")),
      card_body(
        tagList(
        # Log in section
        login_display(),
          
        # Play controls
          conditionalPanel(
            condition = "output.is_logged_in",
                div(
                  class = "d-flex justify-content-center",
                  music_controls(spotify_playlists)
                )
              ),
        # Now playing
          conditionalPanel(
            condition = "output.show_now_playing",
                div(
                  class = "d-flex justify-content-center",
                  now_playing_panel("nowplaying")
                )
          ),
            )
          )
        ),
        

    # 🎼 ATC Section
    card(
      class = "mb-4 w-100 chill-card",
      full_screen = FALSE,
      card_header(class = "text-center", h3("atc")),
      card_body(
          div(
            class = "d-flex align-items-center justify-content-center",
            div(
              class = "atc-select w-100",
              style = "position: relative;",
              selectInput("atc_stream", "choose a ATC stream:", choices = names(atc_streams))
            )
          ),
        tags$audio(
          id = "atc_audio", controls = NA, style = "width: 100%;",
          src = atc_streams[[1]], type = "audio/mpeg"
        ),
        volume_slider("atc_volume")
      )
    ),

    # ⏱ Listening Time Section
    card(
      class = "mb-4 w-100 chill-card",
      full_screen = FALSE,
      card_header(class = "text-center", h3("track")),
      card_body(
        textOutput("timer_display")
      )
    )
  )
}
