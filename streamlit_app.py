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
from streamlit_atc_tracker import atc_tracker

# Set page config
st.set_page_config(page_title="chill atc", layout="centered")
st.title("chill atc")

# Load config
@st.cache_data
def load_yaml(filepath):
    with open(filepath, "r") as f:
        return yaml.safe_load(f)
    
# def embed_audio_player(url, label):
#     st.markdown(f"""
#         <h4>{label}</h4>
#         <audio id="atc-player" controls autoplay>
#             <source src="{url}" type="audio/mpeg">
#             Your browser does not support the audio element.
#         </audio>
#     """, unsafe_allow_html=True)

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
def get_spotify_oauth():
    return SpotifyOAuth(
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET,
        redirect_uri=REDIRECT_URI,
        scope=SCOPE,
        cache_path=CACHE_PATH,
        open_browser=False
    )

oauth = get_spotify_oauth()
params = st.query_params

if "sp" not in st.session_state:
    token_info = oauth.get_cached_token()
    if not token_info and "code" in params:
        try:
            token_info = oauth.get_access_token(code=params["code"])
            st.query_params.clear()
            st.rerun()
        except Exception as e:
            st.error(f"Spotify login failed: {e}")
            st.query_params.clear()

    # Otherwise, try cached token
    #token_info = oauth.get_cached_token()
    #if token_info and not oauth.is_token_expired(token_info):
    if token_info:
        sp = spotipy.Spotify(auth=token_info["access_token"])
        st.session_state.sp = sp
        st.session_state.token_info = token_info

        try:
            user_profile = sp.current_user()
            st.session_state.user_id = user_profile["id"]
        except:
            st.session_state.user_id = str(uuid.uuid4())

# @st.cache_resource
# def get_spotify_session():
#     oauth = SpotifyOAuth(
#         client_id=CLIENT_ID,
#         client_secret=CLIENT_SECRET,
#         redirect_uri=REDIRECT_URI,
#         scope=SCOPE,
#         cache_path=CACHE_PATH,
#         open_browser=False
#     )

#     params = st.query_params
#     if "code" in params and "sp" not in st.session_state:
#         try:
#             st.write((params["code"]))
#             token_info = oauth.get_access_token(code=params["code"])
#             st.session_state.token_info = token_info
#             st.session_state.sp = spotipy.Spotify(auth=token_info["access_token"])
#             user_profile = st.session_state.sp.current_user()
#             st.session_state.user_id = user_profile["id"]
#             st.query_params.clear()
#             st.rerun()
#         except spotipy.oauth2.SpotifyOauthError:
#             st.warning("Spotify login expired. Please log in again.")
#             oauth.cache_handler.delete_cached_token()
#             st.query_params.clear()
#         except Exception as e:
#             st.error(f"Unexpected error during Spotify login: {e}")
#             st.query_params.clear()

#     token_info = oauth.get_cached_token()
#     if token_info:
#         st.session_state.token_info = token_info
#         sp = spotipy.Spotify(auth=token_info["access_token"])
#         return sp, st.session_state.token_info, oauth
#     return None, None, oauth

#sp, token_info, oauth = get_spotify_session()

# if sp:
#     st.session_state.sp = sp
#     st.session_state.token_info = token_info
#     if "user_id" not in st.session_state:
#         try:
#             profile = sp.current_user()
#             st.session_state.user_id = profile["id"]
#         except:
#             st.session_state.user_id = str(uuid.uuid4())
            
# Google Sheets
@st.cache_resource
def get_gsheet_client():
    scope = ["https://www.googleapis.com/auth/spreadsheets", "https://www.googleapis.com/auth/drive"]
    creds = Credentials.from_service_account_info(st.secrets["gsheets"], scopes=scope)
    return gspread.authorize(creds)

gs_client = get_gsheet_client()
sheet = gs_client.open_by_key(SHEET_ID).sheet1

# Load and update times
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

# UI logic
if "sp" not in st.session_state:
    st.markdown("### Please log in to Spotify")
    login_url = oauth.get_authorize_url()
    st.markdown(f'<a href="{login_url}" target="_self">🔐 Login with Spotify</a>', unsafe_allow_html=True)
else:
    st.success("🎶 Logged in with Spotify")
    airport = st.selectbox("Choose an airport for ATC stream:", list(ATC_STREAMS.keys()))
    playlist = st.selectbox("Choose a Spotify playlist:", list(SPOTIFY_PLAYLISTS.keys()))

    st.markdown("""
    **Instructions:**
    - Use the Spotify player below to control your music.
    - Click play to start the ATC stream.
    """)

    if uid:
        st.metric("💡 Your listening time", f"{times[uid]} min")
        st.metric("🌍 Global listening time", f"{times['__total__']} min")

    st.components.v1.iframe(SPOTIFY_PLAYLISTS[playlist], height=80)

    # ATC tracking
    increment = atc_tracker(update_interval=UPDATE_INTERVAL, stream_url=ATC_STREAMS[airport])
    if increment and uid:
        st.write(f"⏱️ ATC played for {increment} sec")
        update_time(uid, increment)
    