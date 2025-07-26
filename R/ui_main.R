ui_main <- function(spotify_playlists, atc_streams, theme) {
  page_fixed(
    theme = theme,

    tags$head(
      tags$script(src = "https://sdk.scdn.co/spotify-player.js"),
      tags$script(src = "spotify-atc.js"),
      tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/icon?family=Material+Icons"),
      tags$style(HTML(sass(sass_file("styles/custom.scss"))))
    ),

    h1("chill atc"),

    # 🎵 Spotify
    card(
      class = "card--primary",
      full_screen = FALSE,

      h2("music"),

      login_display(),

      conditionalPanel(
        condition = "output.is_logged_in",
        music_controls(spotify_playlists)
      ),

      conditionalPanel(
        condition = "output.show_now_playing",
        now_playing_panel("nowplaying")
      )
    ),
        

    # ATC
    card(
      class = "card--primary",
      full_screen = FALSE,
      h2("atc"),

      atc_panel(atc_streams)
    ),
    

    # ⏱ Listening time
    card(
      class = "card--primary",
      full_screen = FALSE,

      h2("airtime"),

      tracking_display()
      
    )
  )
}
