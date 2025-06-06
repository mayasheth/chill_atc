import streamlit as st
import requests
import vlc
import time
import yaml

st.set_page_config(page_title="chill atc soundtrack mixer", layout="centered")
st.title("chill atc")

# Load resource files
def load_yaml(filepath):
    with open(filepath, "r") as f:
        return yaml.safe_load(f)

ATC_STREAMS = load_yaml("resources/atc_streams.yml")
SPOTIFY_PLAYLISTS = load_yaml("resources/spotify_playlists.yml")

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
if st.button("Start ATC Stream"):
    st.session_state["vlc_instance"] = vlc.MediaPlayer(ATC_STREAMS[airport])
    st.session_state["vlc_instance"].play()
    st.success(f"ATC stream from {airport} playing...")

if st.button("Stop ATC Stream"):
    if "vlc_instance" in st.session_state:
        st.session_state["vlc_instance"].stop()
        st.success("ATC stream stopped.")
