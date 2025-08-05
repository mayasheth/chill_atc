SPOTIFY_NS <- "spotify"
ATC_NS <- "atc"
TRACKER_NS <- "tracker"
NOWPLAYING_NS <- "nowplaying"


ui_main <- function(spotify_playlists, atc_streams, theme) {
  page_fixed(
    theme = theme,

    tags$head(
      tags$script(src = "https://sdk.scdn.co/spotify-player.js"),
      tags$style(HTML(sass(sass_file("styles/custom.scss")))),
      tags$script(src = "waveform.js"),
      tags$script(src = "spotify-atc.js"),
      tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/icon?family=Material+Icons")
    ),

    h1("chill atc"),

    # --- 🎵 Spotify ---
    card(
      class = "card--primary",
      full_screen = FALSE,

      h2("music"),

      login_display(SPOTIFY_NS),
      music_controls(SPOTIFY_NS, spotify_playlists),
      now_playing_panel(SPOTIFY_NS)
    ),

    # --- ✈️ ATC ---
    card(
      class = "card--primary",
      full_screen = FALSE,
      h2("atc"),
      atc_panel(ATC_NS, atc_streams)
    ),

    # --- ⏱ Listening time ---
    card(
      class = "card--primary",
      full_screen = FALSE,
      h2("airtime"),
      tracking_display(TRACKER_NS, SPOTIFY_NS)
    )
  )
}
