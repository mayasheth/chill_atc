# --- AUTH HELPERS ---

base64url_encode <- function(bytes) {
  out <- openssl::base64_encode(bytes)
  out <- gsub("\\+", "-", out)
  out <- gsub("/", "_", out)
  out <- gsub("=+$", "", out)
  return(out)
}

generate_pkce <- function() {
  verifier <- paste0(sample(c(letters, LETTERS, 0:9, "-", ".", "_", "~"), 64, replace = TRUE), collapse = "")
  challenge <- base64url_encode(openssl::sha256(charToRaw(verifier)))

  list(
    verifier = verifier,
    challenge = challenge
  )
}

build_auth_url <- function(client_id, redirect_uri, challenge) {
  query_params <- list(
    client_id = client_id,
    response_type = "code",
    redirect_uri = redirect_uri,
    scope = paste(
      "streaming",
      "user-read-email",
      "user-read-private",
      "user-modify-playback-state",
      "user-read-playback-state",
      sep = " "
    ),
    code_challenge_method = "S256",
    code_challenge = challenge,
    state = "xyz"  # optionally: remove or use a constant/random string if needed
  )

  query_string <- paste(
    lapply(names(query_params), function(key) {
      paste0(URLencode(key, reserved = TRUE), "=", URLencode(query_params[[key]], reserved = TRUE))
    }),
    collapse = "&"
  )

  url <- paste0("https://accounts.spotify.com/authorize?", query_string)
  return(url)
}

exchange_token <- function(code, verifier, client_id, redirect_uri) {
  url <- "https://accounts.spotify.com/api/token"

  response <- POST(
    url,
    encode = "form",
    body = list(
      grant_type = "authorization_code",
      code = code,
      redirect_uri = redirect_uri,
      client_id = client_id,
      code_verifier = verifier
    ),
    content_type("application/x-www-form-urlencoded")
  )

  if (http_error(response)) {
    stop("❌ Token exchange failed: ", content(response, "text"))
  }

  fromJSON(content(response, "text", encoding = "UTF-8"))
}

# --- GSHEETS HELPERS ---

init_gsheets_logger <- function(config, context = NULL) {
  sheet_id <- config[["Sheet ID"]]
  gs4_deauth()
  
  if (context == "deployment") {
    json_txt <- Sys.getenv("GCP_SERVICE_ACCOUNT_JSON")
    creds_path <- tempfile(fileext = ".json")
    writeLines(json_txt, con = creds_path)
  } else {
    creds_path <- config[["GSheets key"]]
  }

  gs4_deauth()
  gs4_auth(path = creds_path, cache = FALSE, use_oob = FALSE)
  sheet_id <- config[["Sheet ID"]]
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

### UI HELPERS ###

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

