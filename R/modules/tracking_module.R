# R/modules/tracking_server.R

trackingServer <- function(id, state, sheet_id, atc_streams, update_interval_sec) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # ---- Fetch initial global total time (once) ----
    observeEvent(TRUE, {
      df <- googlesheets4::read_sheet(sheet_id)
      state$global_total_time <- round(sum(df$duration_seconds, na.rm = TRUE), 1)
    }, once = TRUE)

    # ---- Fetch user total time on login ----
    observeEvent(state$user, {
      req(state$user)
      df <- googlesheets4::read_sheet(sheet_id)
      state$user_total_time <- df |>
        dplyr::filter(user_email == state$user) |>
        dplyr::summarise(total_time = sum(duration_seconds, na.rm = TRUE)) |>
        dplyr::pull(total_time) |>
        round(1)
    })

    # ---- Session time tracking ----
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
              atc_link = atc_streams[[state$atc_stream_selected]],
              duration = round(duration, 1)
            )

            # Refresh global/user totals
            df <- googlesheets4::read_sheet(sheet_id)
            state$global_total_time <- round(sum(df$duration_seconds, na.rm = TRUE), 1)

            if (!is.null(state$user)) {
              state$user_total_time <- df |>
                dplyr::filter(user_email == state$user) |>
                dplyr::summarise(total_time = sum(duration_seconds, na.rm = TRUE)) |>
                dplyr::pull(total_time) |>
                round(1)
            }
          })

          state$update_timer()
        })

      } else if (state$session_active) {
        # Handle session ending
        end_time <- Sys.time()
        duration <- as.numeric(difftime(end_time, state$start_time, units = "secs"))
        state$total_time <- state$total_time + duration
        state$session_active <- FALSE

        upsert_session(
          sheet_id = sheet_id,
          session_id = state$session_id,
          email = state$user %||% "unknown",
          playlist_uri = state$playlist_uri,
          atc_link = atc_streams[[state$atc_stream_selected]],
          duration = round(duration, 1)
        )

        # Refresh user/global totals
        df <- googlesheets4::read_sheet(sheet_id)
        state$global_total_time <- round(sum(df$duration_seconds, na.rm = TRUE), 1)

        if (!is.null(state$user)) {
          state$user_total_time <- df |>
            dplyr::filter(user_email == state$user) |>
            dplyr::summarise(total_time = sum(duration_seconds, na.rm = TRUE)) |>
            dplyr::pull(total_time) |>
            round(1)
        }
      }
    })

    # ---- Reactive output for session status ----
    output$session_active <- reactive({
      state$session_active
    })
    outputOptions(output, ("session_active"), suspendWhenHidden = FALSE)

    # ---- Render formatted outputs for UI ----
    output$session_start_time_seconds <- renderText({
      req(state$start_time)
      seconds_to_time_of_day(state$start_time, tz = "America/Los_Angeles")
    })

    output$session_duration_seconds <- renderText({
      seconds <- round(state$total_time, 1)
      if (seconds == 0) "0" else seconds_to_duration(seconds, "h")
    })

    output$user_total_time_seconds <- renderText({
      req(state$user_total_time)
      if (state$user_total_time == 0) "0" else seconds_to_duration(state$user_total_time, "h")
    })

    output$global_total_time_seconds <- renderText({
      req(state$global_total_time)
      if (state$global_total_time == 0) "0" else seconds_to_duration(state$global_total_time, "h")
    })

    outputOptions(output, ("session_start_time_seconds"), suspendWhenHidden = FALSE)
    outputOptions(output, ("session_duration_seconds"), suspendWhenHidden = FALSE)
    outputOptions(output, ("user_total_time_seconds"), suspendWhenHidden = FALSE)
    outputOptions(output, ("global_total_time_seconds"), suspendWhenHidden = FALSE)
  })
}
