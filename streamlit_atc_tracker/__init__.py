import streamlit.components.v1 as components
import os

# Declare the component (set `path` to local frontend directory if developing)
_component_func = components.declare_component(
    "atc_tracker",
    path=os.path.join(os.path.dirname(__file__), "frontend")
)

def atc_tracker(update_interval=60, stream_url=None):
    """
    Render ATC audio player with given stream URL and report playtime to Streamlit
    every `update_interval` seconds.
    """
    return _component_func(update_interval=update_interval, stream_url=stream_url, default=0)
