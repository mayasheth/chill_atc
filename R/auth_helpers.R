
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
