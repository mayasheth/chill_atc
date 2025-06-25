import streamlit.components.v1 as components
import os

_component_func = components.declare_component(
    "atc_tracker",
    path=os.path.join(os.path.dirname(__file__), "build")  # <-- must exist!
)

def atc_tracker(update_interval=60, stream_url=None):
    return _component_func(
        update_interval=update_interval,
        stream_url=stream_url,
        default=0,
    )
