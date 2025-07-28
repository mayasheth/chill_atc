# R/modules/spotify_server.R

spotifyServer <- function(id, state, spotify_playlists, client_id, redirect_uri, spotify_playing_debounced) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # --- Spotify auth flow ---
    observe({ session$sendCustomMessage("init_verifier", NULL) })

    observeEvent(input$login, {
      pkce <- generate_pkce()
      session$userData$verifier <- pkce$verifier
      session$sendCustomMessage("store_verifier", list(verifier = pkce$verifier))
      url <- build_auth_url(client_id, redirect_uri, pkce$challenge)
      session$sendCustomMessage("redirect_to_spotify", list(url = url))
    })

    observe({
      query <- parseQueryString(session$clientData$url_search)
      code <- query$code
      verifier <- input$code_verifier

      if (!is.null(code) && !is.null(verifier)) {
        token_data <- exchange_token(code, verifier, client_id, redirect_uri)
        state$token <- token_data$access_token

        req <- httr2::request("https://api.spotify.com/v1/me") %>%
          httr2::req_auth_bearer_token(state$token)
        user_resp <- tryCatch(httr2::req_perform(req), error = function(e) NULL)
        if (!is.null(user_resp)) {
          user_info <- httr2::resp_body_json(user_resp)
          state$user <- user_info$email
          output$user_info <- renderText({ paste("logged in as:", user_info$email) })
        }

        session$sendCustomMessage("playback", list(token = state$token))
      }
    })

    observeEvent(input$device_id, {
      state$device_id <- input$device_id
    })


    # --- Playlist selection ---
    observeEvent(input$playlist_choice, {
      selected_name <- input$playlist_choice %||% names(spotify_playlists)[1]
      url <- spotify_playlists[[selected_name]]
      playlist_id <- sub(".*/playlist/([^?]+).*", "\\1", url)
      state$playlist_uri <- paste0("spotify:playlist:", playlist_id)
      session$sendCustomMessage("set_playlist_uri", list(uri = state$playlist_uri))
    })


    # --- Current track updates ---
    observeEvent(input$current_track, {
      state$current_track <- input$current_track
    })

    observeEvent(input$track_progress, {
      state$track_progress <- input$track_progress
    })

    # --- Playback status (debounced reactive for stability) ---
    output$show_now_playing <- reactive({
      isTRUE(spotify_playing_debounced()) &&
        !is.null(state$current_track) &&
        nzchar(state$current_track$name)
    })

    observe({
      outputOptions(output, "show_now_playing", suspendWhenHidden = FALSE)
    })

    # --- Playback controls ---
    observeEvent(input$spotify_play_toggle, {
      session$sendCustomMessage("spotify_play_toggle", list())
    })

    observeEvent(input$btn_next, {
      session$sendCustomMessage("playback_control", list(action = "next"))
    })

    observeEvent(input$btn_prev, {
      session$sendCustomMessage("playback_control", list(action = "prev"))
    })

    observeEvent(input$spotify_restart, {
      session$sendCustomMessage("spotify_restart_playlist", list())
    })

    observeEvent(input$spotify_volume, {
      session$sendCustomMessage("set_volume", list(volume = input$spotify_volume))
    })

    # --- Play status ---
    observeEvent(input$spotify_playing, {
      state$spotify_playing(input$spotify_playing)
    })
    
    # --- Play/pause button UI ---
    output$spotify_play_button <- renderUI({
      icon_name <- if (isTRUE(spotify_playing_debounced())) "pause" else "play_arrow"
      actionButton(ns("spotify_play_toggle"), span(icon_name, class = "material-icons"), class = "btn-circle")
    })
    outputOptions(output, "spotify_play_button", suspendWhenHidden = FALSE)


    # observeEvent(input$spotify_playing, {
    #   icon_name <- if (isTRUE(state$spotify_playing_debounced())) "pause" else "play_arrow"
    #   output$spotify_play_button <- renderUI({
    #     actionButton(("spotify_play_toggle"), span(icon_name, class = "material-icons"), class = "btn-circle")
    #   })
    # }, ignoreInit = FALSE)
    # outputOptions(output, ("spotify_play_button"), suspendWhenHidden = FALSE)

    # --- Login state reactive ---
    output$is_logged_in <- reactive({
      !is.null(state$user)
    })
    outputOptions(output, ("is_logged_in"), suspendWhenHidden = FALSE)

    output$user_email <- renderText({
      req(state$user)
      state$user
    })


    # --- Now playing server ---
    prev_image <- reactiveVal(NULL)
    current_img <- reactiveVal(NULL)

    # ---- Track title ----
    output$track_name <- renderText({
      req(state$current_track)
      state$current_track$name
    })

    # ---- Artist name ----
    output$track_artist <- renderText({
      req(state$current_track)
      state$current_track$artist
    })

    # ---- Track progress (0:00 / 3:45) ----
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

    # ---- Track album art (only updates on change) ----
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