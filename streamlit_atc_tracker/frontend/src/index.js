import React, { useEffect, useRef } from "react";
import { Streamlit, withStreamlitConnection } from "streamlit-component-lib";

function ATCTracker({ args }) {
  const audioRef = useRef(null);
  const { update_interval, stream_url } = args;

  useEffect(() => {
    const audio = audioRef.current;
    if (audio && stream_url) {
      audio.src = stream_url;
    }

    let cumulative = 0;
    let lastTime = Date.now();

    const tick = () => {
      const now = Date.now();
      if (audio && !audio.paused) {
        cumulative += (now - lastTime) / 1000;
      }
      lastTime = now;
    };

    const intervalId = setInterval(tick, 1000);
    const reportId = setInterval(() => {
      Streamlit.setComponentValue(Math.floor(cumulative));
      cumulative = 0;
    }, update_interval * 1000);

    return () => {
      clearInterval(intervalId);
      clearInterval(reportId);
    };
  }, [update_interval, stream_url]);

  return (
    <div>
      <h4 style={{ fontFamily: "sans-serif" }}>🛬 ATC Stream</h4>
      <audio ref={audioRef} controls autoPlay />
    </div>
  );
}

export default withStreamlitConnection(ATCTracker);
