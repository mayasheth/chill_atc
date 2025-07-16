# R/now_playing.R

nowPlayingUI <- function(id) {
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
        tags$p(HTML(paste0("<strong>artist:</strong> ", textOutput(ns("track_artist"), inline = TRUE)))),
        tags$p(HTML(paste0("<strong>album:</strong> ", textOutput(ns("track_album"), inline = TRUE))))
      ),
      div(
        textOutput(ns("track_progress")),
        textOutput(ns("track_position"))
      )
    )
  )
}

nowPlayingServer <- function(id, session_state) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    observeEvent(session_state$current_track, {
      info <- session_state$current_track
      req(info)

      output$track_name <- renderText(info$name)
      output$track_artist <- renderText(info$artist)
      output$track_album <- renderText(info$album)
      output$track_image <- renderUI({
        tags$img(
          src = info$image,
          style = "max-width: 100%; height: auto; border-radius: 8px;"
        )
      })
    }, ignoreNULL = TRUE, ignoreInit = FALSE)

    output$track_position <- renderText({
      req(input$playlist_position)
      paste("track", input$playlist_position$index, "of", input$playlist_position$total)
    })

    output$track_progress <- renderText({
      req(input$track_progress)
      pos <- input$track_progress$position %||% 0
      dur <- input$track_progress$duration %||% 1
      format_time <- function(ms) {
        total_sec <- round(ms / 1000)
        sprintf("%d:%02d", total_sec %/% 60, total_sec %% 60)
      }
      paste(format_time(pos), "/", format_time(dur))
    })
  })
}
