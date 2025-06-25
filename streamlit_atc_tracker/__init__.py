import os
import streamlit.components.v1 as components

# Path to the static frontend directory
_component_func = components.declare_component(
    "atc_tracker",
    path=os.path.join(os.path.dirname(__file__), "frontend")
)

def atc_tracker(update_interval=60, stream_url=None):
    """
    Renders the ATC audio stream tracker component.

    Parameters:
    - update_interval (int): Interval in seconds to report play time.
    - stream_url (str): The ATC audio stream URL to play.

    Returns:
    - int: Number of seconds played during the last interval.
    """
    return _component_func(update_interval=update_interval, stream_url=stream_url, default=0)
