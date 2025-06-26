# streamlit_app.py
import streamlit as st
import os, yaml, uuid, json, time, datetime
import spotipy
import gspread
from spotipy.oauth2 import SpotifyOAuth
from google.oauth2.service_account import Credentials
from streamlit_autorefresh import st_autorefresh
import streamlit.components.v1 as components

# Set page config
st.set_page_config(page_title="chill atc", layout="centered", page_icon=":material/mode_dual:")
st.title("chill atc")

# Load config
@st.cache_data
def load_yaml(filepath):
    with open(filepath, "r") as f:
        return yaml.safe_load(f)
    
def embed_audio_player(url, label):
    player_id = str(uuid.uuid4())  # force new audio block on each change
    st.markdown(f"**{label}**")
    st.markdown(f"""
        <audio id="{player_id}" controls autoplay>
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
    if token_info:
        sp = spotipy.Spotify(auth=token_info["access_token"])
        st.session_state.sp = sp
        st.session_state.token_info = token_info
        try:
            user_profile = sp.current_user()
            st.session_state.user_id = user_profile["id"]
        except:
            st.session_state.user_id = str(uuid.uuid4())
            
# Google Sheets
@st.cache_resource
def get_gsheet_client():
    scope = ["https://www.googleapis.com/auth/spreadsheets", "https://www.googleapis.com/auth/drive"]
    creds = Credentials.from_service_account_info(st.secrets["gsheets"], scopes=scope)
    return gspread.authorize(creds)

@st.cache_resource
def get_sheet(_client):
    return _client.open_by_key(SHEET_ID).sheet1

@st.cache_data(ttl=300)
def load_times(_sheet):
    try:
        data = _sheet.get_all_records()
        return {row["user_id"]: {"minutes": int(row["minutes"]), "submissions": int(row.get("submissions", 0))} for row in data}
    except:
        return {}
    
gs_client = get_gsheet_client()
sheet = get_sheet(gs_client)
times = load_times(sheet)

# Set up user ID
if "user_id" in st.session_state:
    uid = st.session_state.user_id
    times.setdefault(uid, {"minutes": 0, "submissions": 0})
    times.setdefault("__total__", {"minutes": 0, "submissions": 0})
else:
    uid = None

def update_time(uid, seconds):
    if uid:
        minutes = int(seconds / 60)
        times[uid]["minutes"] += minutes
        times[uid]["submissions"] += 1
        times["__total__"]["minutes"] += minutes
        times["__total__"]["submissions"] += 1
        rows = [[user, str(data["minutes"]), str(data["submissions"])] for user, data in times.items()]
        sheet.clear()
        sheet.update(values=[ ["user_id", "minutes", "submissions"] ] + rows, range_name="A1")

# UI logic
if "sp" not in st.session_state:
    st.markdown("### please log in to Spotify")
    login_url = oauth.get_authorize_url()
    st.markdown(f'<a href="{login_url}" target="_self"> :material/login: login with Spotify</a>', unsafe_allow_html=True)
else:
    st.success("logged in with Spotify", icon = ":material/music_cast:")
    airport = st.selectbox("choose an airport ATC stream:", list(ATC_STREAMS.keys()))
    playlist = st.selectbox("choose a Spotify playlist:", list(SPOTIFY_PLAYLISTS.keys()))

    st.markdown("""
    **instructions:**
    - use the Spotify player below to control your music
    - click play to start the ATC stream
    """)

    # Embed Spotify iframe and fallback button in columns
    col_spotify, col_button = st.columns([7, 2])
    with col_spotify:
        components.iframe(SPOTIFY_PLAYLISTS[playlist], height=80)
        # components.html(f"""
        # <iframe src="{SPOTIFY_PLAYLISTS[playlist]}" width="100%" height="80" frameborder="0" allowtransparency="true" allow="encrypted-media"></iframe>
        # """, height=100)
    with col_button:
        playlist_url = SPOTIFY_PLAYLISTS[playlist].split("?")[0]
        st.markdown("**on mobile?**")
        st.link_button("open in app", playlist_url, icon=":material/genres:", use_container_width=True)
    
    #Embed  ATC player
    embed_audio_player(ATC_STREAMS[airport], f"streaming ATC from {airport}")

    st.markdown("---")

    # Initialize session state for manual session tracking
    if "session_active" not in st.session_state:
        st.session_state.session_active = False
    if "session_start_time" not in st.session_state:
        st.session_state.session_start_time = None
    if "session_elapsed" not in st.session_state:
        st.session_state.session_elapsed = 0

    st.markdown("#### track your listening")
    col1, col2, col3, col4 = st.columns(4)
    with col1:
        if st.button("start", key="start_button", icon=":material/timer_play:"):
            st.session_state.session_start_time = time.time()
            st.session_state.session_active = True

    with col2:
        if st.button("stop", key="stop_button", icon=":material/timer_pause:"):
            if st.session_state.session_active and st.session_state.session_start_time:
                st.session_state.session_elapsed = int(time.time() - st.session_state.session_start_time)
            st.session_state.session_active = False

    with col3:
        if st.button("submit", key="submit_button", icon=":material/timer_arrow_up:"):
            elapsed = st.session_state.session_elapsed
            update_time(uid, elapsed)
            st.session_state.session_active = False
            st.session_state.session_elapsed = 0
            st.session_state.session_start_time = None
            st.success("session time submitted!")

    with col4:
        if st.button("reset", key="reset_button", icon=":material/delete_history:"):
            st.session_state.session_elapsed = 0
            st.session_state.session_start_time = None
            st.session_state.session_active = False

    # Auto-refresh using st_autorefresh
    if st.session_state.session_active:
        st_autorefresh(interval=10e3, key="timer_refresh")
        if st.session_state.session_start_time:
            st.session_state.session_elapsed = int(time.time() - st.session_state.session_start_time)

    if uid:
        session_hms = str(datetime.timedelta(seconds=st.session_state.session_elapsed))

        def format_minutes(minutes):
            return f"{minutes // 60:02}:{minutes % 60:02}"

        user_total = format_minutes(times[uid]["minutes"])
        global_total = format_minutes(times["__total__"]["minutes"])

        metric_col1, metric_col2, metric_col3 = st.columns(3)
        metric_col1.metric(":material/flight_takeoff: current session", session_hms)
        metric_col2.metric(":material/travel: your total sessions", user_total)
        metric_col3.metric(":material/connecting_airports: global total sessions", global_total)


