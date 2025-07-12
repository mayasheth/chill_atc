# R/now_playing.R

nowPlayingUI <- function(id) {
  ns <- NS(id)
  tagList(
    uiOutput(ns("track_info")),
    uiOutput(ns("track_progress")),
    sliderInput(ns("spotify_volume"), "🎵 Spotify volume", min = 0, max = 1, value = 0.8, step = 0.05),
    sliderInput(ns("atc_volume"), "🛫 ATC volume", min = 0, max = 1, value = 0.8, step = 0.05)
  )
}

nowPlayingServer <- function(id, session_state) {
  moduleServer(id, function(input, output, session) {
    
    # Send Spotify volume updates to JavaScript
    observeEvent(input$spotify_volume, {
      session$sendCustomMessage("set_volume", list(volume = input$spotify_volume))
    })

    # Send ATC stream volume updates to JavaScript
    observeEvent(input$atc_volume, {
      session$sendCustomMessage("set_atc_volume", list(volume = input$atc_volume))
    })

    # Update the current track display
    observeEvent(session_state$current_track, {
      info <- session_state$current_track

      output$track_info <- renderUI({
        tagList(
          tags$h4(info$name),
          tags$p(paste("by", info$artist)),
          tags$p(HTML(paste("Album:", info$album))),
          tags$img(src = info$image, height = "150px")
        )
      })

      output$track_progress <- renderUI({
        tagList(
          tags$label("Track Progress"),
          tags$progress(
            value = info$position,
            max = info$duration,
            style = "width: 100%; height: 20px;"
          ),
          tags$p(sprintf("%.1f / %.1f sec", info$position / 1000, info$duration / 1000))
        )
      })
    })
  })
}

