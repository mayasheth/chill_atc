import streamlit as st
import streamlit.components.v1 as components
import requests
import time
import uuid
import yaml
import json
import os
import base64
import hashlib
import urllib.parse

# ------------------ Configuration ------------------ #
CLIENT_ID = st.secrets["SPOTIFY_CLIENT_ID"]
REDIRECT_URI = "https://chill-atc-dev.streamlit.app/"
SCOPE = "user-read-playback-state streaming"
AUTH_URL = "https://accounts.spotify.com/authorize"
TOKEN_URL = "https://accounts.spotify.com/api/token"

# ------------------ PKCE Utilities ------------------ #
def generate_code_verifier():
    return base64.urlsafe_b64encode(os.urandom(64)).decode('utf-8').rstrip('=')

def generate_code_challenge(verifier):
    digest = hashlib.sha256(verifier.encode()).digest()
    return base64.urlsafe_b64encode(digest).decode('utf-8').rstrip('=')

# ------------------ First-Time Auth ------------------ #
if "user_id" not in st.session_state:
    st.session_state["user_id"] = str(uuid.uuid4())

if "spotify_token" not in st.session_state and "code" not in st.query_params:
    # Step 1: Generate login link
    verifier = generate_code_verifier()
    challenge = generate_code_challenge(verifier)
    st.session_state["verifier"] = verifier

    params = {
        "client_id": CLIENT_ID,
        "response_type": "code",
        "redirect_uri": REDIRECT_URI,
        "code_challenge_method": "S256",
        "code_challenge": challenge,
        "scope": SCOPE
    }
    login_url = f"{AUTH_URL}?{urllib.parse.urlencode(params)}"
    st.markdown(f"[🔐 Login with Spotify]({login_url})")
    st.stop()

# --- Auth Callback --- #
if "code" in st.query_params and "spotify_token" not in st.session_state:
    code = st.query_params["code"]
    verifier = st.session_state.get("verifier")

if verifier is None:
    # Session expired or opened in new tab
    st.warning("Session expired or invalid. Please click below to log in again.")
    
    # Generate new verifier and challenge
    new_verifier = generate_code_verifier()
    new_challenge = generate_code_challenge(new_verifier)
    
    # Save verifier
    st.session_state["verifier"] = new_verifier

    # Redirect immediately in same session (no new tab)
    redirect_url = f"{AUTH_URL}?{urllib.parse.urlencode({{
        'client_id': CLIENT_ID,
        'response_type': 'code',
        'redirect_uri': REDIRECT_URI,
        'code_challenge_method': 'S256',
        'code_challenge': new_challenge,
        'scope': SCOPE
    }})}"

    # Use JS to redirect so we preserve session_state
    components.html(f"""
    <script>
        window.location.href = "{redirect_url}";
    </script>
    """, height=0)
    st.stop()

    # Token exchange step
    payload = {
        "client_id": CLIENT_ID,
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": REDIRECT_URI,
        "code_verifier": verifier
    }

    r = requests.post(TOKEN_URL, data=payload)
    if r.status_code == 200:
        token_data = r.json()
        st.session_state["spotify_token"] = token_data["access_token"]
        st.experimental_set_query_params()  # Clear code from URL
        st.rerun()
    else:
        st.error("Spotify authentication failed.")
        st.stop()


# ------------------ App Begins (Authenticated) ------------------ #
SPOTIFY_TOKEN = st.session_state["spotify_token"]

st.set_page_config(page_title="chill atc sound mixer", layout="centered")
st.title("chill atc")

def load_yaml(filepath):
    with open(filepath, "r") as f:
        return yaml.safe_load(f)

config = load_yaml("resources/config.yml")
ATC_STREAMS = config["ATC streams"]
SPOTIFY_PLAYLISTS = config["Spotify playlists"]

airport = st.selectbox("Choose an airport for ATC stream:", list(ATC_STREAMS.keys()))
playlist = st.selectbox("Choose a Spotify playlist:", list(SPOTIFY_PLAYLISTS.keys()))
atc_url = ATC_STREAMS[airport]
spotify_iframe_url = SPOTIFY_PLAYLISTS[playlist]

# Time tracking
TIMEFILE = "times.json"
if os.path.exists(TIMEFILE):
    with open(TIMEFILE, "r") as f:
        times = json.load(f)
else:
    times = {}
uid = st.session_state["user_id"]
times.setdefault(uid, 0)
times.setdefault("__total__", 0)

def update_time(uid, seconds):
    times[uid] += seconds
    times["__total__"] += seconds
    with open(TIMEFILE, "w") as f:
        json.dump(times, f)

# Instructions + Display
st.markdown("""
**Instructions:**
- Use the Spotify player below to control your music.
- Click play on the ATC stream.
- Time is tracked only when both are playing.
""")
st.metric("🎧 Your listening time", f"{int(times[uid])} sec")
st.metric("🌍 Global listening time", f"{int(times['__total__'])} sec")

components.iframe(spotify_iframe_url, width=300, height=380)

# Audio + SDK logic
components.html(f"""
<audio id="atc" controls autoplay>
  <source src="{atc_url}?nocache={int(time.time())}" type="audio/mpeg">
</audio>
<script src="https://sdk.scdn.co/spotify-player.js"></script>
<script>
let atc = document.getElementById("atc");
let atcPlaying = false;
let spotifyPlaying = false;
let cumulativeTime = 0;
let lastTime = Date.now();

atc.addEventListener("play", () => {{ atcPlaying = true; }});
atc.addEventListener("pause", () => {{ atcPlaying = false; }});

window.onSpotifyWebPlaybackSDKReady = () => {{
  const token = "{SPOTIFY_TOKEN}";
  const player = new Spotify.Player({{
    name: 'chill-atc',
    getOAuthToken: cb => cb(token),
    volume: 0.5
  }});
  player.addListener('ready', ({ device_id }) => {{
    console.log('Device ready', device_id);
  }});
  player.addListener('player_state_changed', state => {{
    spotifyPlaying = state && !state.paused;
  }});
  player.connect();
}};

function tick() {{
  const now = Date.now();
  const delta = (now - lastTime) / 1000;
  lastTime = now;
  if (atcPlaying && spotifyPlaying) {{
    cumulativeTime += delta;
  }}
}}

setInterval(tick, 1000);
setInterval(() => {{
  if (cumulativeTime >= 5) {{
    fetch("/?time_increment=" + Math.floor(cumulativeTime));
    cumulativeTime = 0;
  }}
}}, 5000);
</script>
""", height=250)

# Sync incoming time
time_increment = st.experimental_get_query_params().get("time_increment", [None])[0]
if time_increment:
    update_time(uid, int(time_increment))
    st.experimental_set_query_params()
    st.rerun()
