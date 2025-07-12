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
      total_time = 0
    )
    
    observe({
      session$sendCustomMessage("init_verifier", NULL)
    })
    
    observeEvent(input$login, {
      cat("🎯 Login button clicked!\n")

      pkce <- generate_pkce()
      cat("🔑 Generated verifier:", pkce$verifier, "\n")

      session$userData$verifier <- pkce$verifier
      session$sendCustomMessage("store_verifier", list(verifier = pkce$verifier))

      url <- build_auth_url(client_id, redirect_uri, pkce$challenge)
      cat("🔗 Redirecting to:", url, "\n")

      session$sendCustomMessage("redirect_to_spotify", list(url = url))
    })
    
    observe({
      query <- parseQueryString(session$clientData$url_search)

      cat("🔍 Parsed query string:\n")
      print(query)

      code <- query$code
      verifier <- input$code_verifier

      if (!is.null(code) && !is.null(verifier)) {
        cat("✅ Got code and verifier\n")
        
        token_data <- exchange_token(code, verifier, client_id, redirect_uri)
        state$token <- token_data$access_token

        output$access_token <- renderText({ paste("Access Token:", substr(state$token, 1, 40), "...") })

        # Get user info
        req <- httr2::request("https://api.spotify.com/v1/me") %>%
          httr2::req_auth_bearer_token(state$token)

        user_resp <- tryCatch(httr2::req_perform(req), error = function(e) NULL)
        if (!is.null(user_resp)) {
          user_info <- httr2::resp_body_json(user_resp)
          state$user <- user_info$email
          output$user_info <- renderText({ paste("Logged in as:", user_info$email) })
        }

        session$sendCustomMessage("playback", list(token = state$token))
      } else {
        cat("⏳ Waiting for both code and verifier...\n")
        cat("code =", code, "\n")
        cat("verifier =", verifier, "\n")
      }
    })
    

    observeEvent(input$playlist_choice, {
      selected_name <- input$playlist_choice
      url <- spotify_playlists[[selected_name]]
      playlist_id <- sub(".*/playlist/([^?]+).*", "\\1", url)
      state$playlist_uri <- paste0("spotify:playlist:", playlist_id)

      cat("🎧 Playlist selected:", selected_name, "\n")
      cat("URI:", state$playlist_uri, "\n")
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
      if (!is.null(state$token)) {
        session$sendCustomMessage("playback", list(token = state$token, context_uri = state$playlist_uri))
      }
    })

    observeEvent(input$btn_play, {
      session$sendCustomMessage("playback_control", list(action = "play"))
    })

    observeEvent(input$btn_pause, {
      session$sendCustomMessage("playback_control", list(action = "pause"))
    })

    observeEvent(input$btn_next, {
      session$sendCustomMessage("playback_control", list(action = "next"))
    })

    # Track both playing state
    observeEvent(input$both_playing, {
      if (input$both_playing) {
        state$start_time <- Sys.time()
        state$session_id <- paste0("session_", digest::digest(state$start_time))
        state$session_active <- TRUE
        cat("🟢 Session started at", state$start_time, "\n")

        # Start periodic update
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
              atc_label = input$atc_stream,
              duration = round(duration, 1)
            )
            cat("🔁 Periodic update at", Sys.time(), "- duration:", round(duration, 1), "\n")
          })
          state$update_timer()
        })
      } else if (state$session_active) {
        end_time <- Sys.time()
        duration <- as.numeric(difftime(end_time, state$start_time, units = "secs"))
        state$total_time <- state$total_time + duration
        state$session_active <- FALSE

        cat("🔴 Session ended at", end_time, "\n")
        cat("👤 User:", state$user, "\n")
        cat("🎧 Playlist:", state$playlist_uri, "\n")
        cat("🛫 ATC:", input$atc_stream, "\n")
        cat("⏱ Duration:", round(duration, 1), "seconds\n\n")

        # Final upsert
        upsert_session(
          sheet_id = sheet_id,
          session_id = state$session_id,
          email = state$user %||% "unknown",
          playlist_uri = state$playlist_uri,
          atc_label = input$atc_stream,
          duration = round(duration, 1)
        )
      }
    })


    output$timer_display <- renderText({
      if (state$session_active) {
        paste("🟢 ATC + Spotify playing together since", format(state$start_time, "%H:%M:%S"))
      } else {
        paste("Total listening time so far:", round(state$total_time, 1), "seconds")
      }
    })
  }
}
