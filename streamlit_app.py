# streamlit_app.py
import streamlit as st
import streamlit.components.v1 as components
import time
import uuid
import yaml
import json
import os
from auth_utils import generate_code_verifier, generate_code_challenge, build_auth_url, exchange_code_for_token

# --- Config ---
CLIENT_ID = st.secrets["SPOTIFY_CLIENT_ID"]
REDIRECT_URI = "https://chill-atc-dev.streamlit.app/"
SCOPE = "user-read-playback-state streaming"

# --- Setup user ID and session ---
if "user_id" not in st.session_state:
    st.session_state["user_id"] = str(uuid.uuid4())

# --- Handle PKCE Spotify auth ---
if "spotify_token" not in st.session_state:
    code = st.query_params.get("code", [None])[0]

    if code:
        verifier = st.session_state.get("verifier")
        if not verifier:
            st.error("Session expired. Please start login again.")
            st.markdown("🔁 <a href=\"\" target=\"_self\">Click here to log in with Spotify</a>", unsafe_allow_html=True)
            st.stop()
        try:
            token = exchange_code_for_token(code, verifier, CLIENT_ID, REDIRECT_URI)
            st.session_state["spotify_token"] = token
            st.experimental_set_query_params()
            st.rerun()
        except Exception as e:
            st.error(f"Token exchange failed: {e}")
            st.stop()
    else:
        verifier = generate_code_verifier()
        challenge = generate_code_challenge(verifier)
        st.session_state["verifier"] = verifier
        login_url = build_auth_url(CLIENT_ID, REDIRECT_URI, SCOPE, challenge)
        st.markdown(f'<a href="{login_url}" target="_self">🔐 Login with Spotify</a>', unsafe_allow_html=True)
        st.stop()

# --- Authenticated ---
SPOTIFY_TOKEN = st.session_state["spotify_token"]

st.set_page_config(page_title="chill atc sound mixer", layout="centered")
st.title("chill atc")

# --- Load config ---
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

# --- Time tracking ---
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

st.markdown("""
**Instructions:**
- Use the Spotify player below to control your music.
- Click play on the ATC stream.
- Time is tracked only when both are playing.
""")
st.metric("🎧 Your listening time", f"{int(times[uid])} sec")
st.metric("🌍 Global listening time", f"{int(times['__total__'])} sec")

components.iframe(spotify_iframe_url, width=300, height=380)

components.html(f"""
<audio id=\"atc\" controls autoplay>
  <source src=\"{atc_url}?nocache={int(time.time())}\" type=\"audio/mpeg\">
</audio>
<script src=\"https://sdk.scdn.co/spotify-player.js\"></script>
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
  player.addListener('ready', ({{ device_id }}) => {{ console.log('Spotify Player ready', device_id); }});
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
