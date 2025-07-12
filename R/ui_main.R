ui_main <- function(spotify_playlists, atc_streams) {
  fluidPage(
    titlePanel("chill ATC"),

    tags$head(
      tags$script(src = "https://sdk.scdn.co/spotify-player.js"),
      tags$script(src = "spotify-atc.js"),
    ),
    
    actionButton("login", "Log in with Spotify"),
    verbatimTextOutput("auth_code"),
    verbatimTextOutput("access_token"),
    verbatimTextOutput("user_info"),
    selectInput("playlist_choice", "Choose a Spotify playlist:", choices = names(spotify_playlists)),
    selectInput("atc_stream", "Choose ATC stream:", choices = names(atc_streams)),
    tags$audio(id = "atc_audio", controls = NA, style = "width: 100%;", tags$source(src = "", type = "audio/mpeg")),
    actionButton("play", "▶️ Play in browser"),
    fluidRow(
      column(4, actionButton("btn_play", "▶️ Play")),
      column(4, actionButton("btn_pause", "⏸️ Pause")),
      column(4, actionButton("btn_next", "⏭️ Next"))
    ),
    nowPlayingUI("nowplaying"),
    textOutput("timer_display")
  )
}
