# R/server_main.R

server_main <- function(config, spotify_playlists, atc_streams, sheet_id, client_id, redirect_uri) {
  function(input, output, session) {
    update_interval_sec <- config[["Update interval (min.)"]] * 60 * 1000

    state <- reactiveValues(
      token = NULL,
      user = NULL,
      playlist_uri = "spotify:playlist:5PMoeSrcXv4OrURJi48z9c",
      current_track = NULL,
      session_active = FALSE,
      session_id = NULL,
      update_timer = NULL,
      start_time = NULL,
      total_time = 0,
      device_id = NULL
    )

    observe({ session$sendCustomMessage("init_verifier", NULL) })

    observeEvent(input$login, {
      cat("🎯 Login button clicked!\n")
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
          output$user_info <- renderText({ paste("Logged in as:", user_info$email) })
        }

        session$sendCustomMessage("playback", list(token = state$token))
      }
    })

    observeEvent(input$device_id, {
      state$device_id <- input$device_id
    })

    observeEvent(input$playlist_choice, {
      selected_name <- input$playlist_choice
      url <- spotify_playlists[[selected_name]]
      playlist_id <- sub(".*/playlist/([^?]+).*", "\\1", url)
      state$playlist_uri <- paste0("spotify:playlist:", playlist_id)
      session$sendCustomMessage("set_playlist_uri", list(uri = state$playlist_uri))
    })

    observeEvent(input$current_track, {
      state$current_track <- input$current_track
    })

    nowPlayingServer("nowplaying", state)

    observeEvent(input$atc_stream, {
      url <- atc_streams[[input$atc_stream]]
      session$sendCustomMessage("update_atc", list(url = url))
    })

    observeEvent(input$play, {
      req(state$token, state$playlist_uri, state$device_id)
      session$sendCustomMessage("playback", list(
        token = state$token,
        context_uri = state$playlist_uri
      ))
    })
    
    # Play / Pause toggle
    observeEvent(input$spotify_play_toggle, {
      session$sendCustomMessage("spotify_play_toggle", list())
    })

    # Next track
    observeEvent(input$btn_next, {
      session$sendCustomMessage("playback_control", list(action = "next"))
    })

    # Restart playlist from top
    observeEvent(input$spotify_restart, {
      session$sendCustomMessage("spotify_restart_playlist", list())
    })
    

    observeEvent(input$both_playing, {
      if (input$both_playing) {
        state$start_time <- Sys.time()
        state$session_id <- paste0("session_", digest::digest(state$start_time))
        state$session_active <- TRUE
        state$update_timer <- reactiveTimer(update_interval_sec, session)

        observe({
          req(state$session_active, state$session_id)
          isolate({
            duration <- as.numeric(difftime(Sys.time(), state$start_time, units = "secs"))
            upsert_session(
              sheet_id = sheet_id,
              session_id = state$session_id,
              email = state$user %||% "unknown",
              playlist_uri = state$playlist_uri,
              atc_link = atc_streams[[input$atc_stream]],
              duration = round(duration, 1)
            )
          })
          state$update_timer()
        })
      } else if (state$session_active) {
        end_time <- Sys.time()
        duration <- as.numeric(difftime(end_time, state$start_time, units = "secs"))
        state$total_time <- state$total_time + duration
        state$session_active <- FALSE

        upsert_session(
          sheet_id = sheet_id,
          session_id = state$session_id,
          email = state$user %||% "unknown",
          playlist_uri = state$playlist_uri,
          atc_link = atc_streams[[input$atc_stream]],
          duration = round(duration, 1)
        )
      }
    })

    observeEvent(input$atc_volume, {
      session$sendCustomMessage("set_atc_volume", list(volume = input$atc_volume))
    })

    observeEvent(input$spotify_volume, {
      session$sendCustomMessage("set_volume", list(volume = input$spotify_volume / 100))
    })

    output$auth_ui <- renderUI({
      if (is.null(state$user)) {
        actionButton("login", "Log in with Spotify")
      } else {
        div(paste("✅ Logged in as:", state$user))
      }
    })

    output$playerUI <- renderUI({
      req(state$user)
      tagList(
        selectInput("playlist_choice", "Choose a Spotify playlist:", choices = names(spotify_playlists)),
        sliderInput("spotify_volume", "Spotify Volume", min = 0, max = 100, value = 80, step = 1),
        actionButton("play", "▶️ Play in browser"),
        fluidRow(
          column(4, actionButton("btn_play", "▶️ Play")),
          column(4, actionButton("btn_pause", "⏸️ Pause")),
          column(4, actionButton("btn_next", "⏭️ Next"))
        )
      )
    })

    output$timer_display <- renderText({
      if (state$session_active) {
        paste("🟢 ATC + Spotify playing together since", format(state$start_time, "%H:%M:%S"))
      } else {
        paste("Total listening time so far:", round(state$total_time, 1), "seconds")
      }
    })

    output$is_logged_in <- reactive({
      !is.null(state$user)
    })
    outputOptions(output, "is_logged_in", suspendWhenHidden = FALSE)

    output$user_display <- renderText({
      paste("✅ Logged in as:", state$user)
    })
  }
}
