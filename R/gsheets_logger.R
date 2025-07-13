
init_gsheets_logger <- function(config) {
  creds_path <- config[["GSheets key"]]
  sheet_id <- config[["Sheet ID"]]
  gs4_deauth()
  gs4_auth(path = creds_path, cache = FALSE, use_oob = FALSE)
  return(sheet_id)
}

upsert_session <- function(sheet_id, session_id, email, playlist_uri, atc_link, duration) {
  ss <- gs4_get(sheet_id)
  sheet_data <- read_sheet(ss)
  new_row <- tibble::tibble(
    session_id = session_id,
    email = email,
    playlist_uri = playlist_uri,
    atc_label = atc_link,
    duration = duration,
    updated_at = Sys.time()
  )
  if ("session_id" %in% names(sheet_data) && session_id %in% sheet_data$session_id) {
    row_index <- which(sheet_data$session_id == session_id)
    range <- paste0("A", row_index + 1)
    range_write(ss, new_row, range = range, col_names = FALSE)
  } else {
    sheet_append(ss, new_row)
  }
}
