# streamlit_app.py
import streamlit as st
import os
import secrets
import urllib.parse
import yaml
import uuid
from auth_utils import generate_code_verifier, generate_code_challenge, build_auth_url, exchange_code_for_token

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
REDIRECT_URI = "https://chill-atc-dev.streamlit.app/
SCOPE = "user-read-playback-state user-modify-playback-state user-read-currently-playing"

# Session state variables
if "access_token" not in st.session_state:
    st.session_state.access_token = None
if "verifier" not in st.session_state:
    st.session_state.verifier = None

# Handle redirect with code
params = st.query_params
if "code" in params:
    try:
        token = exchange_code_for_token(
            code=params["code"],
            verifier=st.session_state.verifier,
            client_id=CLIENT_ID,
            redirect_uri=REDIRECT_URI
        )
        st.session_state.access_token = token
        st.success("Spotify authentication successful!")
    except Exception as e:
        st.error(f"Failed to authenticate: {e}")

# Show login button if not authenticated
if not st.session_state.access_token:
    st.markdown("### Please log in to Spotify")
    verifier = generate_code_verifier()
    challenge = generate_code_challenge(verifier)
    st.session_state.verifier = verifier
    login_url = build_auth_url(CLIENT_ID, REDIRECT_URI, SCOPE, challenge)
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
