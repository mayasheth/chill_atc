# R/server_main.R

server_main <- function(config, spotify_playlists, atc_streams, sheet_id, client_id, redirect_uri) {
  function(input, output, session) {

    # =============================
    # 🔧 Global State Initialization
    # =============================
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
      user_total_time = NA,
      global_total_time = NA,
      device_id = NULL,
      playlist_position = NULL,
      track_progress = NULL
    )

    # Initialize global listening time
    observeEvent(TRUE, {
      df <- googlesheets4::read_sheet(sheet_id)
      state$global_total_time <- round(sum(df$duration_seconds, na.rm = TRUE), 1)
    }, once = TRUE)

    # =============================
    # 🔐 Spotify PKCE Auth Flow
    # =============================
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

    

    # =============================
    # 🎵 Spotify Playlist Selection
    # =============================
    observeEvent(input$playlist_choice, {
      selected_name <- input$playlist_choice %||% names(spotify_playlists)[1]
      url <- spotify_playlists[[selected_name]]
      playlist_id <- sub(".*/playlist/([^?]+).*", "\\1", url)
      state$playlist_uri <- paste0("spotify:playlist:", playlist_id)
      session$sendCustomMessage("set_playlist_uri", list(uri = state$playlist_uri))
    })

    observeEvent(input$current_track, {
      state$current_track <- input$current_track
    })

    output$show_now_playing <- reactive({
      !is.null(state$current_track) && nzchar(state$current_track$name)
    })
    outputOptions(output, "show_now_playing", suspendWhenHidden = FALSE)

    observeEvent(input$track_progress, {
      state$track_progress <- input$track_progress
    })

    nowPlayingServer("nowplaying", state)


    # =============================
    # ✈️ ATC Stream Selection
    # =============================
    observeEvent(input$atc_stream, {
      url <- atc_streams[[input$atc_stream]]
      cat("🚨 Sending update_atc message with URL:", url, "\n")
      session$sendCustomMessage("update_atc", list(url = url))
    })

    # =============================
    # ▶️ Playback Controls
    # =============================
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
    

    # =============================
    # ⏱️ Session Time Tracking (ATC + Spotify both playing)
    # =============================

    # Get initial listening time for user upon login
    observeEvent(state$user, {
      req(state$user)
      df <- googlesheets4::read_sheet(sheet_id)
      state$user_total_time <- df %>%
        dplyr::filter(user_email == state$user) %>%
        dplyr::summarize(total_time = sum(duration_seconds, na.rm = TRUE)) %>%
        dplyr::pull(total_time) %>%
        round(1)
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
            
            # Update row
            upsert_session(
              sheet_id = sheet_id,
              session_id = state$session_id,
              email = state$user %||% "unknown",
              playlist_uri = state$playlist_uri,
              atc_link = atc_streams[[input$atc_stream]],
              duration = round(duration, 1)
            )
            
            # Recalculate global total
            df <- googlesheets4::read_sheet(sheet_id)
            state$global_total_time <- round(sum(df$duration_seconds, na.rm = TRUE), 1)

            # Recalculate user total if logged in
            if (!is.null(state$user)) {
              state$user_total_time <- df %>%
                dplyr::filter(user_email == state$user) %>%
                dplyr::summarize(total_time = sum(duration_seconds, na.rm = TRUE)) %>%
                dplyr::pull(total_time) %>% 
                round(1)
            }
          })

          # Re-trigger on timer interval
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

        # Refresh user + global time after session ends
        df <- googlesheets4::read_sheet(sheet_id)

        if (!is.null(state$user)) {
          state$user_total_time <- df %>%
            dplyr::filter(user_email == state$user) %>%
            dplyr::summarize(total_time = sum(duration_seconds, na.rm = TRUE)) %>%
            dplyr::pull(total_time) %>% 
            round(1)
        }

        state$global_total_time <- round(sum(df$duration_seconds, na.rm = TRUE), 1)
      }
    })

    # =============================
    # 🔊 Volume Control
    # =============================
    observeEvent(input$atc_volume, {
      session$sendCustomMessage("set_atc_volume", list(volume = input$atc_volume))
    })

    observeEvent(input$spotify_volume, {
      session$sendCustomMessage("set_volume", list(volume = input$spotify_volume))
    })

    # =============================
    # 🎛️ UI Elements
    # =============================

    # Helper functions to format
    seconds_to_time_of_day <- function(seconds, tz = "America/Los_Angeles") {
      format(seconds, "%H:%M", tz)
    }

    seconds_to_duration <- function(seconds, resolution = "s") {
      seconds <- floor(abs(seconds))
      if (seconds == 0) return("0")

      h <- seconds %/% 3600
      m <- (seconds %% 3600) %/% 60
      s <- seconds %% 60

      parts <- list()

      if (resolution == "h") {
        if (h >= 1) {
          return(paste(format(h, big.mark = ","), "h"))
        } else {
          resolution <- "m"  # fallback to minute format
        }
      }

      if (resolution == "m") {
        if (h > 0) parts <- c(parts, paste(h, "h"))
        if (m > 0) parts <- c(parts, paste(m, "m"))
        if (length(parts) == 0) parts <- "0"
        return(paste(parts, collapse = " "))
      }

      if (resolution == "s") {
        if (h > 0) parts <- c(parts, paste(h, "h"))
        if (m > 0) parts <- c(parts, paste(m, "m"))
        if (s > 0) parts <- c(parts, paste(s, "s"))
        if (length(parts) == 0) parts <- "0"
        return(paste(parts, collapse = " "))
      }

      stop("Invalid resolution. Choose from 'h', 'm', or 's'.")
    }

  
  # Tracking text outputs
  output$session_active <- reactive({
    state$session_active
  })
  outputOptions(output, "session_active", suspendWhenHidden = FALSE)

  output$is_logged_in <- reactive({
    !is.null(state$user)
  })
  outputOptions(output, "is_logged_in", suspendWhenHidden = FALSE)

  # Start time of current session (formatted as HH:MM:SS)
  output$session_start_time_seconds <- renderText({
    req(state$start_time)
    seconds_to_time_of_day(state$start_time)
  })
  outputOptions(output, "session_start_time_seconds", suspendWhenHidden = FALSE)

  # Duration of current session (formatted as "1 h 30 m", etc.)
  output$session_duration_seconds <- renderText({
    seconds <- round(state$total_time, 1)
    if (seconds == 0) "0" else seconds_to_duration(seconds, "h")
  })
  outputOptions(output, "session_duration_seconds", suspendWhenHidden = FALSE)

  # Total listening time for the current user
  output$user_total_time_seconds <- renderText({
    req(state$user_total_time)
    if (state$user_total_time == 0) "0" else seconds_to_duration(state$user_total_time, "h")
  })
  outputOptions(output, "user_total_time_seconds", suspendWhenHidden = FALSE)

  # Global total listening time
  output$global_total_time_seconds <- renderText({
    req(state$global_total_time)
    if (state$global_total_time == 0) "0" else seconds_to_duration(state$global_total_time, "h")
  })
  outputOptions(output, "global_total_time_seconds", suspendWhenHidden = FALSE)



    # Playback controls
    observeEvent(input$spotify_playing, {
      icon_name <- if (isTRUE(input$spotify_playing)) "pause" else "play_arrow"
      output$play_pause_button <- renderUI({
        actionButton("spotify_play_toggle", span(icon_name, class = "material-icons"), class = "btn-circle")
      })
    }, ignoreInit = FALSE)    

    output$is_logged_in <- reactive({
      !is.null(state$user)
    })
    
    outputOptions(output, "is_logged_in", suspendWhenHidden = FALSE)

    output$user_email <- renderText({
      req(state$user)
      state$user
    })
    
  }
}

