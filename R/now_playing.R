# R/now_playing.R

nowPlayingUI <- function(id) {
  ns <- NS(id)
  tagList(
    uiOutput(ns("track_info")),
    uiOutput(ns("track_progress"))
  )
}

nowPlayingServer <- function(id, session_state) {
  moduleServer(id, function(input, output, session) {

    # Update the current track display
    observeEvent(session_state$current_track, {
      info <- session_state$current_track

      output$track_info <- renderUI({
        tagList(
          tags$h4(info$name),
          tags$p(paste("by", info$artist)),
          tags$p(HTML(paste("Album:", info$album))),
          #tags$img(src = info$image, height = "150px"),
          if (!is.null(session_state$playlist_image)) {
            tagList(
              tags$p("Playlist:"),
              tags$img(src = session_state$playlist_image, height = "100px")
            )
          }
        )
      })

      output$track_progress <- renderUI({
        tagList(
          tags$label("Track progress"),
          tags$progress(
            value = info$position,
            max = info$duration,
            style = "width: 100%; height: 20px;"
          ),
          tags$p(sprintf("%d:%02d / %d:%02d",
            as.integer(info$position / 1000) %/% 60,
            as.integer(info$position / 1000) %% 60,
            as.integer(round(info$duration / 1000)) %/% 60,
            as.integer(round(info$duration / 1000)) %% 60
          ))
        )
      })
    })
  })
}
