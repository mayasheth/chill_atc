console.log('✅ spotify-atc.js loaded');
console.log('✅ Defining window.onSpotifyWebPlaybackSDKReady');

window.spotifyIsPlaying = false;
window.atcIsPlaying = false;
window.lastStatus = null;
window.trackPoller = null;

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

// Save verifier BEFORE redirect
Shiny.addCustomMessageHandler("store_verifier", (msg) => {
  window.code_verifier = msg.verifier;
  console.log("💾 code_verifier stored:", msg.verifier);
});
//
//Shiny.addCustomMessageHandler("store_verifier", (msg) => {
//  console.log("📦 Storing verifier before redirect:", msg.verifier);
//  localStorage.setItem("spotify_code_verifier", msg.verifier);
//});

// Restore verifier AFTER redirect
document.addEventListener("DOMContentLoaded", waitForShinyAndSendVerifier);

Shiny.addCustomMessageHandler("redirect_to_spotify", (msg) => {
  if (msg.url && window.code_verifier) {
    console.log("🌍 Redirecting to Spotify with verifier:", window.code_verifier);
    localStorage.setItem("spotify_code_verifier", window.code_verifier);
    window.location.href = msg.url;
  }
});


function attachAtcListeners() {
  const atc = document.getElementById("atc_audio");
  if (!atc) {
    console.warn("❌ ATC audio element not found!");
    return;
  }
  console.log("✅ Found ATC audio element:", atc);

  if (atc.dataset.listenersAttached) return;
  atc.dataset.listenersAttached = true;

  ['play', 'playing', 'pause', 'ended'].forEach(ev => {
    atc.addEventListener(ev, () => {
      const isPlaying = !atc.paused && atc.readyState >= 2;
      window.atcIsPlaying = isPlaying;
      console.log(`📻 ATC event: ${ev}, paused=${atc.paused}, readyState=${atc.readyState}, isPlaying=${isPlaying}`);
      Shiny.setInputValue("atc_playing", isPlaying, { priority: "event" });
    });
  });

  // fallback polling
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

window.onSpotifyWebPlaybackSDKReady = () => {
  console.log('Spotify SDK Ready');



  Shiny.addCustomMessageHandler('playback', (msg) => {
    window.spotifyToken = msg.token;
    if (!window.spotifyPlayer) {
      const player = new Spotify.Player({
        name: 'Shiny Web Player',
        getOAuthToken: cb => { cb(window.spotifyToken); },
        volume: 0.8
      });
      window.spotifyPlayer = player;
        player.addListener('ready', ({ device_id }) => {
          console.log('Spotify Player ready with Device ID', device_id);
          window.device_id = device_id;
          Shiny.setInputValue('device_id', device_id);

          fetch("https://api.spotify.com/v1/me/player", {
            method: "PUT",
            headers: {
              Authorization: `Bearer ${window.spotifyToken}`,
              "Content-Type": "application/json"
            },
            body: JSON.stringify({
              device_ids: [device_id],
              play: true
            })
          });
        });
        
        player.addListener('initialization_error', ({ message }) => console.error('init_error', message));
        player.addListener('authentication_error', ({ message }) => console.error('auth_error', message));
        player.addListener('account_error', ({ message }) => console.error('account_error', message));
        player.addListener('playback_error', ({ message }) => console.error('playback_error', message));

        
      player.addListener('player_state_changed', (state) => {
        if (!state) return;
        const track = state.track_window.current_track;
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
                Shiny.setInputValue('current_track',
                  Object.assign({}, window.latestTrack, { position: state.position }),
                  { priority: 'event' });
              });
            }
          }, 1000);
        }
        Shiny.setInputValue('spotify_playing', window.spotifyIsPlaying, { priority: 'event' });
      });
      player.connect();
        
        Shiny.addCustomMessageHandler('playback_control', (msg) => {
          if (!window.spotifyPlayer || !msg.action) return;

          const actions = {
            play: () => window.spotifyPlayer.resume(),
            pause: () => window.spotifyPlayer.pause(),
            next: () => window.spotifyPlayer.nextTrack()
          };

          const actionFn = actions[msg.action];
          if (actionFn) {
            console.log(`🎛 Performing action: ${msg.action}`);
            actionFn().catch(err => console.error("❌ Playback control failed:", err));
          } else {
            console.warn(`⚠️ Unknown action: ${msg.action}`);
          }
        });

        
    }
      
      setTimeout(() => {
        if (msg.context_uri && window.device_id) {
          fetch(`https://api.spotify.com/v1/me/player/play?device_id=${window.device_id}`, {
            method: 'PUT',
            body: JSON.stringify({ context_uri: msg.context_uri }),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${msg.token}`
            }
          });
        }
      }, 500);
    
  });

  Shiny.addCustomMessageHandler('set_volume', (msg) => {
    if (window.spotifyPlayer && typeof msg.volume === 'number') {
      window.spotifyPlayer.setVolume(msg.volume);
    }
  });

  Shiny.addCustomMessageHandler('set_atc_volume', (msg) => {
    const audio = document.getElementById('atc_audio');
    if (audio && typeof msg.volume === 'number') {
      audio.volume = msg.volume;
    }
  });

  Shiny.addCustomMessageHandler('update_atc', (msg) => {
    const audio = document.getElementById('atc_audio');
    const source = audio.querySelector('source');
    if (audio && source) {
      source.src = msg.url;
      audio.load();
    }
  });

  Shiny.addCustomMessageHandler('play_atc_now', (msg) => {
    const audio = document.getElementById('atc_audio');
    if (!audio) return;
    const source = audio.querySelector('source');
    if (!source || !source.src) return;
    audio.play().catch(err => console.error('ATC play() failed:', err));
  });
};


setInterval(() => {
  const both = window.spotifyIsPlaying && window.atcIsPlaying;
  console.log("🎧 Spotify:", window.spotifyIsPlaying, "| ✈️ ATC:", window.atcIsPlaying, "| 🤝 Both:", both);

  if (both !== window.lastStatus) {
    window.lastStatus = both;
    console.log("🚨 Sending both_playing:", both);
    Shiny.setInputValue('both_playing', both, { priority: 'event' });
  }
}, 1000);

document.addEventListener("DOMContentLoaded", () => {
  console.log("📦 DOM fully loaded, attaching ATC listeners");
  attachAtcListeners();
});
