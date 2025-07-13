// ================================
// ✅ GLOBAL STATE VARIABLES
// ================================
console.log('✅ spotify-atc.js loaded');
console.log('✅ Defining window.onSpotifyWebPlaybackSDKReady');

window.spotifyIsPlaying = false;
window.atcIsPlaying = false;
window.lastStatus = null;
window.trackPoller = null;

let player = null;
let playerReady = false;
let playerDeviceId = null;
let isPlaying = false;

// ================================
// 🔐 AUTHENTICATION FLOW HELPERS
// ================================
function waitForShinyAndSendVerifier() {
  const verifier = localStorage.getItem("spotify_code_verifier");
  if (!verifier) {
    console.log("⚠️ No verifier in localStorage");
    return;
  }
  if (typeof Shiny === "undefined" || !Shiny.setInputValue) {
    console.log("⏳ Waiting for Shiny...");
    setTimeout(waitForShinyAndSendVerifier, 100);
    return;
  }
  console.log("✅ Sending verifier to Shiny:", verifier);
  Shiny.setInputValue("code_verifier", verifier, { priority: "event" });
  localStorage.removeItem("spotify_code_verifier");
}

document.addEventListener("DOMContentLoaded", () => {
  waitForShinyAndSendVerifier();
  console.log("📦 DOM fully loaded, attaching ATC listeners");
  attachAtcListeners();
});

// ================================
// 🔄 SHINY MESSAGE HANDLERS (Auth, Playlist, Control)
// ================================
Shiny.addCustomMessageHandler("store_verifier", (msg) => {
  window.code_verifier = msg.verifier;
  console.log("💾 code_verifier stored:", msg.verifier);
});

Shiny.addCustomMessageHandler("redirect_to_spotify", (msg) => {
  if (msg.url && window.code_verifier) {
    console.log("🌍 Redirecting to Spotify with verifier:", window.code_verifier);
    localStorage.setItem("spotify_code_verifier", window.code_verifier);
    window.location.href = msg.url;
  }
});

Shiny.addCustomMessageHandler("set_playlist_uri", (msg) => {
  if (msg.uri) {
    sessionStorage.setItem("spotify_playlist_uri", msg.uri);
    console.log("💾 Stored playlist URI:", msg.uri);
  }
});

// ================================
// ▶️ SPOTIFY PLAYBACK CONTROL HANDLERS
// ================================
Shiny.addCustomMessageHandler("spotify_play_toggle", function(_) {
  if (!playerReady || !player) {
    console.warn("⚠️ Spotify player not ready yet.");
    return;
  }

  const playlistUri = sessionStorage.getItem("spotify_playlist_uri");
  const token = sessionStorage.getItem("spotify_access_token");

  player.getCurrentState().then(state => {
    if (!state || !state.track_window.current_track) {
      // Nothing is playing — start selected playlist from top
      if (!playlistUri || !token || !playerDeviceId) {
        console.warn("⚠️ Missing playlistUri/token/deviceId");
        return;
      }
      fetch(`https://api.spotify.com/v1/me/player/play?device_id=${playerDeviceId}`, {
        method: "PUT",
        body: JSON.stringify({
          context_uri: playlistUri,
          offset: { position: 0 },
          position_ms: 0
        }),
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`
        }
      }).then(() => {
        console.log("✅ Started selected playlist from top.");
      }).catch(console.error);
    } else {
      const currentContext = state.context && state.context.uri;
      if (currentContext !== playlistUri) {
        // Different playlist — switch to selected playlist from top
        fetch(`https://api.spotify.com/v1/me/player/play?device_id=${playerDeviceId}`, {
          method: "PUT",
          body: JSON.stringify({
            context_uri: playlistUri,
            offset: { position: 0 },
            position_ms: 0
          }),
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${token}`
          }
        }).then(() => {
          console.log("🔁 Switched to selected playlist from top.");
        }).catch(console.error);
      } else {
        // Same playlist — resume or pause
        if (isPlaying) {
          player.pause();
        } else {
          player.resume();
        }
      }
    }
  });
});

Shiny.addCustomMessageHandler("spotify_restart_playlist", function(_) {
  if (!playerReady || !player) return;

  const token = sessionStorage.getItem("spotify_access_token");
  const playlistUri = sessionStorage.getItem("spotify_playlist_uri");

  if (!playlistUri || !token || !playerDeviceId) {
    console.warn("⚠️ Missing playlistUri/token/deviceId");
    return;
  }

  fetch(`https://api.spotify.com/v1/me/player/play?device_id=${playerDeviceId}`, {
    method: "PUT",
    body: JSON.stringify({
      context_uri: playlistUri,
      offset: { position: 0 },
      position_ms: 0
    }),
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${token}`
    }
  }).then(() => {
    console.log("✅ Restarted playlist from top");
  }).catch(err => {
    console.error("❌ Failed to restart playlist:", err);
  });
});

// ================================
// 📻 ATC AUDIO LISTENER SETUP
// ================================
function attachAtcListeners() {
  const atc = document.getElementById("atc_audio");
  if (!atc) {
    console.warn("❌ ATC audio element not found!");
    return;
  }
  console.log("✅ Found ATC audio element:", atc);

  if (atc.dataset.listenersAttached) return;
  atc.dataset.listenersAttached = true;

  ["play", "playing", "pause", "ended"].forEach(ev => {
    atc.addEventListener(ev, () => {
      const isPlaying = !atc.paused && atc.readyState >= 2;
      window.atcIsPlaying = isPlaying;
      console.log(`📻 ATC event: ${ev}, paused=${atc.paused}, readyState=${atc.readyState}, isPlaying=${isPlaying}`);
      Shiny.setInputValue("atc_playing", isPlaying, { priority: "event" });
    });
  });

  setInterval(() => {
    if (!atc) return;
    const isPlaying = !atc.paused && atc.readyState >= 2;
    if (isPlaying !== window.atcIsPlaying) {
      window.atcIsPlaying = isPlaying;
      console.log("🕒 ATC poll: isPlaying =", isPlaying);
      Shiny.setInputValue("atc_playing", isPlaying, { priority: "event" });
    }
  }, 2000);
}

// 🎧 ATC stream switch handler
Shiny.addCustomMessageHandler('update_atc', (msg) => {
  const audio = document.getElementById('atc_audio');
  const source = audio.querySelector('source');
  if (audio && source) {
    console.log("🔄 Switching ATC stream to:", msg.url);
    source.src = msg.url;
    audio.load();
  }
});


// ================================
// 🎧 SPOTIFY WEB PLAYBACK SDK INIT
// ================================
window.onSpotifyWebPlaybackSDKReady = () => {
  console.log("Spotify SDK Ready");

  Shiny.addCustomMessageHandler("playback", (msg) => {
    window.spotifyToken = msg.token;
    sessionStorage.setItem("spotify_access_token", msg.token);
      
    if (!window.spotifyPlayer) {
      player = new Spotify.Player({
        name: "Shiny Web Player",
        getOAuthToken: cb => { cb(window.spotifyToken); },
        volume: 0.8
      });
      window.spotifyPlayer = player;

      player.addListener("ready", ({ device_id }) => {
        console.log("Spotify Player ready with Device ID", device_id);
        playerDeviceId = device_id;
        playerReady = true;
        Shiny.setInputValue("device_id", device_id);
        fetch("https://api.spotify.com/v1/me/player", {
          method: "PUT",
          headers: {
            Authorization: `Bearer ${window.spotifyToken}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({ device_ids: [device_id], play: false })
        }).then(() => {
          console.log("✅ Device transferred to Web Playback SDK");
        });
      });

      player.addListener("initialization_error", ({ message }) => console.error("init_error", message));
      player.addListener("authentication_error", ({ message }) => console.error("auth_error", message));
      player.addListener("account_error", ({ message }) => console.error("account_error", message));
      player.addListener("playback_error", ({ message }) => console.error("playback_error", message));

      player.addListener("player_state_changed", (state) => {
        if (!state) return;
        const track = state.track_window.current_track;
        isPlaying = !state.paused;
        window.spotifyIsPlaying = !state.paused;
        window.latestTrack = {
          name: track.name,
          artist: track.artists[0].name,
          album: track.album.name,
          image: track.album.images[0].url,
          duration: state.duration
        };
        if (!window.trackPoller) {
          window.trackPoller = setInterval(() => {
            if (window.spotifyIsPlaying) {
              player.getCurrentState().then(state => {
                if (!state) return;
                Shiny.setInputValue("current_track",
                  Object.assign({}, window.latestTrack, { position: state.position }),
                  { priority: "event" });
              });
            }
          }, 1000);
        }
        Shiny.setInputValue("spotify_playing", window.spotifyIsPlaying, { priority: "event" });
      });

      Shiny.addCustomMessageHandler("playback_control", (msg) => {
  if (!player || !msg.action) return;
  const actions = {
    play: () => player.resume(),
    pause: () => player.pause(),
    next: () => player.nextTrack()
  };
  const actionFn = actions[msg.action];
  if (actionFn) {
    console.log(`🎛 Performing action: ${msg.action}`);
    actionFn().catch(err => console.error("❌ Playback control failed:", err));
  } else {
    console.warn(`⚠️ Unknown action: ${msg.action}`);
  }
});

      player.connect();
    }
  });

  Shiny.addCustomMessageHandler("set_volume", (msg) => {
    if (player && typeof msg.volume === "number") {
      player.setVolume(msg.volume);
    }
  });
};

// ================================
// ⏱️ SYNC STATE REPORTER
// ================================
setInterval(() => {
  const both = window.spotifyIsPlaying && window.atcIsPlaying;
  if (both !== window.lastStatus) {
    window.lastStatus = both;
    console.log("🚨 Sending both_playing:", both);
    Shiny.setInputValue("both_playing", both, { priority: "event" });
  }
}, 1000);
