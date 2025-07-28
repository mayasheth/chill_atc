# R/modules/atc_server.R

atcServer <- function(id, state, atc_streams, atc_playing_debounced) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # --- ATC stream selection ---
    observeEvent(input$atc_stream, {
      state$atc_stream_selected <- input$atc_stream
      session$sendCustomMessage("update_atc", list(url = atc_streams[[input$atc_stream]]))
    })

    # --- Toggle play/pause button ---
    observeEvent(input$atc_play_toggle, {
      session$sendCustomMessage("atc_play_toggle", list())
    })

    # --- Volume ---
    observeEvent(input$atc_volume, {
      session$sendCustomMessage("set_atc_volume", list(volume = input$atc_volume))
    })

    # --- Play status ---
    observeEvent(input$atc_playing, {
      state$atc_playing(input$atc_playing)
    })

    # --- Play button UI (with icon state) ---
    output$atc_play_button <- renderUI({
      icon_name <- if (isTRUE(atc_playing_debounced())) "pause" else "play_arrow"
      actionButton(ns("atc_play_toggle"), span(icon_name, class = "material-icons"), class = "btn-circle")
    })
    outputOptions(output, "atc_play_button", suspendWhenHidden = FALSE)

    # --- Live label: "live from (CODE)" ---
    output$atc_stream_label <- renderUI({
      req(atc_playing_debounced(), input$atc_stream)

      if (isTRUE(atc_playing_debounced())) {
        code <- gsub(".*\\(([^)]+)\\)", "\\1", input$atc_stream)  # Extract 3-letter airport code
        div(class = "atc-stream-label", HTML(paste0("live from <b>", code, "</b>")))
      }
    })
    outputOptions(output, ("atc_stream_label"), suspendWhenHidden = FALSE)

    # --- Ensure JS listeners are attached only once ---
    session$onFlushed(function() {
      session$sendCustomMessage("init_atc_audio", list())
    }, once = TRUE)
  })
}
