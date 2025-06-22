# streamlit_app.py (Spotipy version)
import streamlit as st
import os
import yaml
import uuid
import spotipy
from spotipy.oauth2 import SpotifyOAuth

# Set page config
st.set_page_config(page_title="chill atc", layout="centered")
st.title("chill atc")

# Load config
@st.cache_data
def load_yaml(filepath):
    with open(filepath, "r") as f:
        return yaml.safe_load(f)

config = load_yaml("resources/config.yml")
ATC_STREAMS = config["ATC streams"]
SPOTIFY_PLAYLISTS = config["Spotify playlists"]

# Configuration
CLIENT_ID = st.secrets["SPOTIFY_CLIENT_ID"]
CLIENT_SECRET = st.secrets["SPOTIFY_CLIENT_SECRET"]
REDIRECT_URI = st.secrets["SPOTIFY_REDIRECT_URI"]
SCOPE = "user-read-playback-state user-modify-playback-state user-read-currently-playing"
CACHE_PATH = ".spotify_token_cache"

# Setup Spotify OAuth handler
oauth = SpotifyOAuth(
    client_id=CLIENT_ID,
    client_secret=CLIENT_SECRET,
    redirect_uri=REDIRECT_URI,
    scope=SCOPE,
    cache_path=CACHE_PATH,
    open_browser=False
)

# Handle redirect with code
params = st.query_params
if "code" in params:
    try:
        token_info = oauth.get_access_token(params["code"])
        st.session_state.sp = spotipy.Spotify(auth=token_info["access_token"])
        st.session_state.token_info = token_info
        st.rerun()  # Force refresh after authentication
    except Exception as e:
        st.error(f"Failed to authenticate: {e}")

# Show login button if not authenticated
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
    - The ATC stream will play automatically.
    """)

    # Embed Spotify player (iframe)
    st.components.v1.iframe(SPOTIFY_PLAYLISTS[playlist], height=80)

    # Embed ATC audio player
    def embed_audio_player(url):
        unique_id = uuid.uuid4()
        st.markdown(f"""
            <audio id="{unique_id}" controls autoplay>
                <source src="{url}" type="audio/mpeg">
                Your browser does not support the audio element.
            </audio>
        """, unsafe_allow_html=True)

    embed_audio_player(ATC_STREAMS[airport])
