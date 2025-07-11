import streamlit as st
import requests
import time
import yaml

st.set_page_config(
    page_title="chill atc sound mixer",
    page_icon="‍✈️",  # emoji or relative path to image
    layout="centered"
)

st.title("chill atc")

## helper functions
def load_yaml(filepath):
    with open(filepath, "r") as f:
        return yaml.safe_load(f)

def embed_audio_player(url):
    timestamp = int(time.time())
    st.audio(f"{url}?nocache={timestamp}", format="audio/mpeg", start_time=0)

# Load config
config = load_yaml("resources/config.yml")
ATC_STREAMS = config["ATC streams"]
SPOTIFY_PLAYLISTS = config["Spotify playlists"]

# User selection
airport = st.selectbox("Choose an airport for ATC stream:", list(ATC_STREAMS.keys()))
playlist = st.selectbox("Choose a Spotify playlist:", list(SPOTIFY_PLAYLISTS.keys()))

# Instructions
st.markdown("""
**Instructions:**
- Use the Spotify player below to control your music.
- Click the play button to start ATC stream.
- Volume mixing must be done manually.
""")

# Spotify embedded player
st.components.v1.iframe(SPOTIFY_PLAYLISTS[playlist], width=300, height=380)

# ATC player
selected_url = ATC_STREAMS[airport]
st.write(f"Streaming from: {selected_url}")
embed_audio_player(selected_url)

