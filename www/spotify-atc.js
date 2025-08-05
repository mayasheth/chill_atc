// ================================
// ✅ GLOBAL STATE VARIABLES
// ================================
console.log('✅ spotify-atc.js loaded');
console.log('✅ Defining window.onSpotifyWebPlaybackSDKReady');

window.spotifyIsPlaying = false;
window.atcIsPlaying = false;
window.lastStatus = null;
window.trackPoller = null;
window.atcVolume = 0.8;
window.spotifyVolume = 0.8;

let player = null;
let playerReady = false;
let playerDeviceId = null;
let isPlaying = false;

// ================================
// 🔧 NAMESPACE INPUT IDS
// ================================
const NS_SPOTIFY = "spotify";
const NS_ATC = "atc";
const NS_TRACKER = "tracker";

// Helper
function ns(ns, id) {
  return `${ns}-${id}`;
}

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
  Shiny.setInputValue(ns(NS_SPOTIFY, "code_verifier"), verifier, { priority: "event" });
  localStorage.removeItem("spotify_code_verifier");
}

document.addEventListener("DOMContentLoaded", () => {
  waitForShinyAndSendVerifier();
  console.log("📦 DOM fully loaded");
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

    // Reset waveform params
    const canvas = document.getElementById("waveform-canvas");
    if (canvas) resetWaveParams("spotify");

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
// 📻 ATC SET UP
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
    if (atc.dataset.suppress) return;

    const isPlaying = !atc.paused && atc.readyState >= 2;
    window.atcIsPlaying = isPlaying;
    console.log(`📻 ATC event: ${ev}, isPlaying=${isPlaying}`);
    Shiny.setInputValue(ns(NS_ATC, "atc_playing"), isPlaying, { priority: "event" });
  });
});

  setInterval(() => {
    if (!atc) return;
    const isPlaying = !atc.paused && atc.readyState >= 2;
    if (isPlaying !== window.atcIsPlaying) {
      window.atcIsPlaying = isPlaying;
      console.log("🕒 ATC poll: isPlaying =", isPlaying);
      Shiny.setInputValue(ns(NS_ATC, "atc_playing"), isPlaying, { priority: "event" });
    }
  }, 2000);
}


// ================================
// ATC CONTROLS
// ================================

function handleAtcStreamUpdate(newUrl) {
  const audio = document.getElementById("atc_audio");
  if (!audio) {
    console.warn("❌ ATC audio element not found!");
    return;
  }

  const wasPlaying = !audio.paused && audio.readyState >= 2;

  // Prevent update events from firing during switch
  audio.dataset.suppress = "true";

  console.log(`🔄 Switching ATC stream to ${newUrl} (wasPlaying=${wasPlaying})`);
  audio.src = newUrl;
  audio.load();

  // If it was already playing, resume after a short delay
  if (wasPlaying) {
    const playPromise = audio.play();
    if (playPromise !== undefined) {
      playPromise
        .then(() => console.log("▶️ Resumed ATC playback after stream switch"))
        .catch(err => console.warn("⚠️ Could not resume ATC playback:", err));
    }
  }

  // Re-enable event sending
  setTimeout(() => {
    delete audio.dataset.suppress;
  }, 300); // adjust if needed

  // Reset waveform params
  resetWaveParams("atc");
}

Shiny.addCustomMessageHandler("init_atc_audio", (_) => {
  console.log("🎧 Received message to initialize ATC audio listeners");
  attachAtcListeners();
});

Shiny.addCustomMessageHandler("atc_play_toggle", (_) => {
  const audio = document.getElementById("atc_audio");
  if (!audio) return;

  if (audio.paused) {
    audio.play();
    Shiny.setInputValue(ns(NS_ATC, "atc_playing"), true, { priority: "event" });
    console.log(`Playing ATC stream!`);
  } else {
    audio.pause();
    Shiny.setInputValue(ns(NS_ATC, "atc_playing"), false, { priority: "event" });
    console.log(`Pausing ATC stream!`);
  }
});

Shiny.addCustomMessageHandler("update_atc", (msg) => {
  handleAtcStreamUpdate(msg.url);
});

Shiny.addCustomMessageHandler("set_atc_volume", (msg) => {
  const audio = document.getElementById("atc_audio");
  if (audio && typeof msg.volume === "number") {
    audio.volume = msg.volume;
    window.atcVolume = msg.volume;
    console.log("🔉 ATC volume set to", msg.volume);
  }
});


// ================================
// 🎧 SPOTIFY WEB PLAYBACK SDK INIT
// ================================
window.onSpotifyWebPlaybackSDKReady = () => {
  console.log("🎵 Spotify SDK Ready");

  player = new Spotify.Player({
    name: "Shiny Web Player",
    getOAuthToken: cb => cb(sessionStorage.getItem("spotify_access_token")),
    volume: 0.8
  });
  window.spotifyPlayer = player;

  player.addListener("ready", ({ device_id }) => {
    console.log("✅ Spotify Player ready with Device ID", device_id);
    playerDeviceId = device_id;
    playerReady = true;
    Shiny.setInputValue(ns(NS_SPOTIFY, "device_id"), device_id);

    fetch("https://api.spotify.com/v1/me/player", {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${sessionStorage.getItem("spotify_access_token")}`,
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
      
      const currentIndex = state.track_window.current_track
        ? state.track_window.previous_tracks.length + 1
        : 0;
      const totalTracks = state.track_window.previous_tracks.length +
                          state.track_window.next_tracks.length + 1;

      Shiny.setInputValue(ns(NS_SPOTIFY, "playlist_position"), {
        index: currentIndex,
        total: totalTracks
      }, { priority: "event" });
      
      if (!window.trackPoller) {
        window.trackPoller = setInterval(() => {
          if (window.spotifyIsPlaying) {
            player.getCurrentState().then(state => {
              if (!state || !state.track_window.current_track) return;

              const pos = state.position;
              const dur = state.duration;

              // Update track progress
              Shiny.setInputValue(ns(NS_SPOTIFY, "track_progress"), {
                position: pos,
                duration: dur
              }, { priority: "event" });

              // Update current track
              Shiny.setInputValue(ns(NS_SPOTIFY,"current_track"),
                Object.assign({}, window.latestTrack, { position: pos }),
                { priority: "event" }
              );

              // Update playlist position
              const totalTracks = state.track_window.previous_tracks.length +
                                  state.track_window.next_tracks.length + 1;
              const currentIndex = state.track_window.previous_tracks.length + 1;

              Shiny.setInputValue(ns(NS_SPOTIFY, "playlist_position"), {
                index: currentIndex,
                total: totalTracks
              }, { priority: "event" });
            });
          }
        }, 1000);
      }

    Shiny.setInputValue(ns(NS_SPOTIFY, "spotify_playing"), window.spotifyIsPlaying, { priority: "event" });
  });

  Shiny.addCustomMessageHandler("playback_control", (msg) => {
    if (!player || !msg.action) return;
    const actions = {
      play: () => player.resume(),
      pause: () => player.pause(),
      next: () => player.nextTrack(),
      prev: () => player.previousTrack()
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
};

// ================================
// 💾 TOKEN STORAGE HANDLER
// ================================
Shiny.addCustomMessageHandler("playback", (msg) => {
  window.spotifyToken = msg.token;
  sessionStorage.setItem("spotify_access_token", msg.token);
});

// ================================
// 🔊 VOLUME CONTROL HANDLER
// ================================
Shiny.addCustomMessageHandler("set_volume", (msg) => {
  if (!playerReady || !player) {
    console.warn("⚠️ Spotify player not ready for volume change");
    return;
  }

  if (typeof msg.volume === "number") {
    player.setVolume(msg.volume).then(() => {
      window.spotifyVolume = msg.volume;
      console.log("🔊 Spotify volume set to:", msg.volume);
    }).catch(err => {
      console.error("❌ Failed to set Spotify volume:", err);
    });
  }
});


// ================================
// ⏱️ SYNC STATE REPORTER
// ================================
setInterval(() => {
  const both = window.spotifyIsPlaying && window.atcIsPlaying;
  if (both !== window.lastStatus) {
    window.lastStatus = both;
    console.log("🚨 Sending both_playing:", both);
    Shiny.setInputValue(ns(NS_TRACKER, "both_playing"), both, { priority: "event" });
  }
}, 1000);


// ================================
// WAVEFORM
// ================================
document.addEventListener("DOMContentLoaded", () => {
  const canvas = document.getElementById("waveform-canvas");
  if (canvas) {
    startWaveform({
      canvasId: "waveform-canvas",
      spotifyReactive: () => window.spotifyIsPlaying,
      atcReactive: () => window.atcIsPlaying,
      spotifyVolumeGetter: () => window.spotifyVolume || 0.8,
      atcVolumeGetter: () => {
        const audio = document.getElementById("atc_audio");
        return audio ? audio.volume : 0.8;
      }
    });

  } else {
    console.warn("⚠️ waveform-canvas not found when initializing waveform");
  }
});

