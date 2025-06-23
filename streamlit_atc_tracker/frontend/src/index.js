import React, { useEffect } from "react";
import ReactDOM from "react-dom";
import { Streamlit, withStreamlitConnection } from "streamlit-component-lib";

const ATCPlayer = ({ args }) => {
  const streamUrl = args.stream_url;
  const updateInterval = args.update_interval;

  useEffect(() => {
    const atc = document.getElementById("atc-player");
    if (atc) atc.src = streamUrl;

    let lastTime = Date.now();
    let cumulative = 0;

    const tick = () => {
      const now = Date.now();
      if (atc && !atc.paused) {
        cumulative += (now - lastTime) / 1000;
      }
      lastTime = now;
    };

    const interval1 = setInterval(tick, 1000);
    const interval2 = setInterval(() => {
      Streamlit.setComponentValue(Math.floor(cumulative));
      cumulative = 0;
    }, updateInterval * 1000);

    return () => {
      clearInterval(interval1);
      clearInterval(interval2);
    };
  }, [streamUrl, updateInterval]);

  return (
    <div>
      <h4 style={{ fontFamily: "sans-serif" }}>🛬 ATC Stream</h4>
      <audio id="atc-player" controls autoPlay>
        <source src={streamUrl} type="audio/mpeg" />
        Your browser does not support the audio element.
      </audio>
    </div>
  );
};

const WrappedComponent = withStreamlitConnection(ATCPlayer);
ReactDOM.render(<WrappedComponent />, document.getElementById("root"));

