ui_main <- function(spotify_playlists, atc_streams, theme) {
  fluidPage(
    titlePanel("chill ATC"),
    theme = theme,
    
    tags$head(
      tags$script(src = "https://sdk.scdn.co/spotify-player.js"),
      tags$script(src = "spotify-atc.js")
    ),

    ## ---- Spotify Section ----
    hr(),
    h3("🎵 music"),

    conditionalPanel(
      condition = "!output.is_logged_in",
      actionButton("login", "Log in with Spotify")
    ),
    
    conditionalPanel(
      condition = "output.is_logged_in",
      tagList(
        textOutput("user_display"),
        selectInput("playlist_choice", "Choose a Spotify playlist:", choices = names(spotify_playlists)),
        #actionButton("play", "▶️ Play in browser"),       
        fluidRow(
          column(4, actionButton("spotify_play_toggle", "▶️ Play / Pause")),
          column(4, actionButton("btn_next", "⏭️ Next")),
          column(4,  actionButton("spotify_restart", "🔁 Restart Playlist"))
        ),
        sliderInput("spotify_volume", "Spotify volume", min = 0, max = 1, value = 0.8, step = 0.05),
        nowPlayingUI("nowplaying")
      )
    ),

    ## ---- ATC Section ----
    hr(),
    h3("🛫 ATC"),

    selectInput("atc_stream", "Choose an ATC stream:", choices = names(atc_streams)),
    tags$audio(id = "atc_audio", controls = NA, style = "width: 100%;",
               tags$source(src = "", type = "audio/mpeg")),
    sliderInput("atc_volume", "ATC volume", min = 0, max = 1, value = 0.8, step = 0.05),

    ## ---- Listening Time Section ----
    hr(),
    h3("⏱ Listening time"),

    textOutput("timer_display")
  )
}
