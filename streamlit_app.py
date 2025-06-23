# streamlit_app.py
import streamlit as st
import os
import yaml
import uuid
import json
import time
import spotipy
import gspread
from spotipy.oauth2 import SpotifyOAuth
from google.oauth2.service_account import Credentials
from streamlit_js_eval import streamlit_js_eval

# Set page config
st.set_page_config(page_title="chill atc", layout="centered")
st.title("chill atc")

# Load config
@st.cache_data
def load_yaml(filepath):
    with open(filepath, "r") as f:
        return yaml.safe_load(f)

def embed_audio_player(url, label):
    unique_id = uuid.uuid4()
    st.markdown(f"""
        <h4>{label}</h4>
        <audio id="atc-player" controls autoplay>
            <source src="{url}" type="audio/mpeg">
            Your browser does not support the audio element.
        </audio>
    """, unsafe_allow_html=True)

config = load_yaml("resources/config.yml")
ATC_STREAMS = config["ATC streams"]
SPOTIFY_PLAYLISTS = config["Spotify playlists"]
SHEET_ID = config["Sheet ID"]
UPDATE_INTERVAL = config.get("Time update interval (seconds)", 60)

# Configuration
CLIENT_ID = st.secrets["SPOTIFY_CLIENT_ID"]
CLIENT_SECRET = st.secrets["SPOTIFY_CLIENT_SECRET"]
REDIRECT_URI = st.secrets["SPOTIFY_REDIRECT_URI"]
SCOPE = "user-read-playback-state user-modify-playback-state user-read-currently-playing user-read-private"
CACHE_PATH = ".spotify_token_cache"

@st.cache_resource
def get_spotify_session():
    oauth = SpotifyOAuth(
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET,
        redirect_uri=REDIRECT_URI,
        scope=SCOPE,
        cache_path=CACHE_PATH,
        open_browser=False
    )

    params = st.query_params
    if "code" in params and "sp" not in st.session_state:
        try:
            token_info = oauth.get_access_token(code=params["code"])
            st.session_state.token_info = token_info
            st.session_state.sp = spotipy.Spotify(auth=token_info["access_token"])
            user_profile = st.session_state.sp.current_user()
            st.session_state.user_id = user_profile["id"]
            st.query_params.clear()
            st.rerun()
        except spotipy.oauth2.SpotifyOauthError:
            st.warning("Spotify login expired. Please log in again.")
            oauth.cache_handler.delete_cached_token()
            st.query_params.clear()
        except Exception as e:
            st.error(f"Unexpected error during Spotify login: {e}")
            st.query_params.clear()

    token_info = oauth.get_cached_token()
    if token_info:
        st.session_state.token_info = token_info
        sp = spotipy.Spotify(auth=token_info["access_token"])
        return sp, st.session_state.token_info, oauth
    return None, None, oauth


sp, token_info, oauth = get_spotify_session()

if sp and "sp" not in st.session_state:
    st.session_state.sp = sp
    st.session_state.token_info = token_info
    try:
        user_profile = st.session_state.sp.current_user()
        st.session_state.user_id = user_profile["id"]
    except:
        st.session_state.user_id = str(uuid.uuid4())

# Setup Google Sheets (modern auth)
@st.cache_resource
def get_gsheet_client():
    scope = ["https://www.googleapis.com/auth/spreadsheets", "https://www.googleapis.com/auth/drive"]
    creds = Credentials.from_service_account_info(st.secrets["gsheets"], scopes=scope)
    return gspread.authorize(creds)

gs_client = get_gsheet_client()
sheet = gs_client.open_by_key(SHEET_ID).sheet1

# Load times into dict
try:
    times_data = sheet.get_all_records()
    times = {row["user_id"]: int(row["minutes"]) for row in times_data}
except:
    times = {}

if "user_id" in st.session_state:
    uid = st.session_state.user_id
    times.setdefault(uid, 0)
    times.setdefault("__total__", 0)
else:
    uid = None

def update_time(uid, seconds):
    if uid:
        minutes = int(seconds / 60)
        times[uid] += minutes
        times["__total__"] += minutes
        rows = [[user, t] for user, t in times.items()]
        sheet.clear()
        sheet.update([["user_id", "minutes"]] + rows)

# Show login link if not authenticated
if "sp" not in st.session_state:
    st.markdown("### Please log in to Spotify")
    login_url = oauth.get_authorize_url()
    st.markdown(f'<a href="{login_url}" target="_self">🔐 Login with Spotify</a>', unsafe_allow_html=True)
else:
    st.write("🎶 You are logged in with Spotify!")

    # Stream selections
    airport = st.selectbox("Choose an airport for ATC stream:", list(ATC_STREAMS.keys()))
    playlist = st.selectbox("Choose a Spotify playlist:", list(SPOTIFY_PLAYLISTS.keys()))

    # Instructions
    st.markdown("""
    **Instructions:**
    - Use the Spotify player below to control your music.
    - Click play to start the ATC stream.
    """)

    if uid:
        # Display listening time in minutes
        st.metric("🎧 Your listening time", f"{times[uid]} min")
        st.metric("🌍 Global listening time", f"{times['__total__']} min")

    # Embed Spotify player (iframe)
    st.components.v1.iframe(SPOTIFY_PLAYLISTS[playlist], height=80)

    # Embed ATC audio player with label
    embed_audio_player(ATC_STREAMS[airport], label=f"🛬 ATC stream from {airport}")

    # Bidirectional time tracker (no reload)
    if "cumulative_time" not in st.session_state:
        st.session_state.cumulative_time = 0

    time_placeholder = st.empty()

    st.components.v1.html(f"""
    <script>

      let atc = document.getElementById("atc-player");
      let lastTime = Date.now();
      let cumulative = 0;

      function tick() {{
        const now = Date.now();
        if (atc && !atc.paused) {{
          cumulative += (now - lastTime) / 1000;
        }}
        lastTime = now;
      }}

      setInterval(tick, 1000);
      setInterval(() => {{
        if (cumulative >= {UPDATE_INTERVAL}) {{
            window.parent.postMessage({
            type: 'streamlit:setComponentValue',
            key: 'atc-time',
            value: Math.floor(cumulative)
            }, '*');          
            cumulative = 0;
        }}
      }}, {UPDATE_INTERVAL * 1000});
    </script>
    """, height=0)

    time_increment = streamlit_js_eval(key="atc-time")
    if time_increment and uid:
        st.write(f"⏱️ Received time increment: {time_increment} seconds")
        update_time(uid, int(time_increment))
        st.session_state.cumulative_time += int(time_increment)
        time_placeholder.info(f"Session total: {st.session_state.cumulative_time} sec")
