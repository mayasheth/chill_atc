// --- waveform.js ---

// --- Utility functions ---

function getCssVar(name, alpha = 1) {
  const hex = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  const [r, g, b] = hex.replace("#", "").match(/.{2}/g).map(x => parseInt(x, 16));
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function generateWaveParams(height) {
  return {
    baseFrequency: Math.random() * (0.15 - 0.1) + 0.1,
    jitterFrequency: Math.random() * (0.2 - 0.1) + 0.1,
    baseAmplitude: height / 4,
    jitterAmplitude: Math.random() * (12 - 2) + 2,
    timeScale: Math.random() * (10 - 4) + 4
  };
}

function smoothStep(current, target, smoothing = 0.0001) {
  return current + (target - current) * smoothing;
}

// --- Main waveform setup ---
function startWaveform({
  canvasId,
  spotifyReactive,
  atcReactive,
  spotifyVolumeGetter,
  atcVolumeGetter
}) {
  const canvas = document.getElementById(canvasId);
  const ctx = canvas.getContext("2d");
  
  let width = canvas.offsetWidth;
  let height = canvas.offsetHeight;

  const dpr = window.devicePixelRatio || 1;
  canvas.width = width * dpr;
  canvas.height = height * dpr;
  ctx.scale(dpr, dpr);

  canvas.width = width;
  canvas.height = height;

  let smoothed = {
    atc: { amp: 0, jitter: 0 },
    spotify: { amp: 0, jitter: 0 }
  };


  // Resize canvas on window resize
  function resizeCanvas() {
    const dpr = window.devicePixelRatio || 1;
    width = canvas.offsetWidth;
    height = canvas.offsetHeight;
    canvas.width = width * dpr;
    canvas.height = height * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  window.addEventListener("resize", resizeCanvas);

  // --- Drawing helpers using scoped ctx, width, height ---

  function createStrokeGradient(darkColorVar, lightColorVar) {
    const gradient = ctx.createLinearGradient(0, height, 0, 0);
    gradient.addColorStop(0, getCssVar(lightColorVar));
    gradient.addColorStop(0.25, getCssVar(darkColorVar));
    gradient.addColorStop(0.5, getCssVar(darkColorVar));
    gradient.addColorStop(0.75, getCssVar(darkColorVar));
    gradient.addColorStop(1, getCssVar(lightColorVar));
    return gradient;
  }

  function drawSideFade() {
    const fadeWidth = 60;

    const left = ctx.createLinearGradient(0, 0, fadeWidth, 0);
    left.addColorStop(0, getCssVar("--brand-card_background", 1));
    left.addColorStop(1, getCssVar("--brand-card_background", 0));
    ctx.fillStyle = left;
    ctx.fillRect(0, 0, fadeWidth, height);

    const right = ctx.createLinearGradient(width - fadeWidth, 0, width, 0);
    right.addColorStop(0, getCssVar("--brand-card_background", 0));
    right.addColorStop(1, getCssVar("--brand-card_background", 1));
    ctx.fillStyle = right;
    ctx.fillRect(width - fadeWidth, 0, fadeWidth, height);
  }

  function drawWaveform(params, time, darkColorVar, lightColorVar, isPlaying, volume) {
    const centerY = height / 2;
    // const ampScale = isPlaying ? 1 : 0.2;
    // const freqScale = isPlaying ? 1 : 0.3;

    // const amp = params.baseAmplitude * ampScale * volume;
    // const jitterAmp = params.jitterAmplitude * ampScale * volume;
    // const freq = params.baseFrequency * freqScale;
    // const jitterFreq = params.jitterFrequency * freqScale;
    // const timeScale = params.timeScale;

    params._ampTarget = isPlaying ? 1 : 0.2;
    params._freqTarget = isPlaying ? 1 : 0.3;
    params._ampCurrent = params._ampCurrent || params._ampTarget;
    params._freqCurrent = params._freqCurrent || params._freqTarget;

    // Smoothly approach target
    const smoothing = 0.05; // smaller = smoother
    params._ampCurrent += (params._ampTarget - params._ampCurrent) * smoothing;
    params._freqCurrent += (params._freqTarget - params._freqCurrent) * smoothing;

    const amp = params.baseAmplitude * params._ampCurrent * volume;
    const jitterAmp = params.jitterAmplitude * params._ampCurrent * volume;
    const freq = params.baseFrequency * params._freqCurrent;
    const jitterFreq = params.jitterFrequency * params._freqCurrent;
    const timeScale = params.timeScale;

    ctx.beginPath();
    ctx.moveTo(0, centerY);

    for (let x = 0; x < width; x++) {
      const baseY = amp * Math.sin(freq * x + time * 2);
      const jitterY = jitterAmp * Math.sin(jitterFreq * x + time * timeScale);
      ctx.lineTo(x, centerY + baseY + jitterY);
    }

    ctx.strokeStyle = createStrokeGradient(darkColorVar, lightColorVar);
    ctx.lineWidth = 3;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.stroke();
  }

  // --- State variables ---
  let atcParams = generateWaveParams(height);
  let spotifyParams = generateWaveParams(height);
  let lastATCStream = null;
  let lastPlaylist = null;

  function draw() {
    const time = Date.now() / 1000;

    ctx.fillStyle = getCssVar("--brand-card_background", 0.3);
    ctx.fillRect(0, 0, width, height);

    drawWaveform(atcParams, time, "--brand-tertiary", "--brand-secondary", atcReactive(), atcVolumeGetter());
    drawWaveform(spotifyParams, time, "--brand-spotify_green", "--brand-light_green", spotifyReactive(), spotifyVolumeGetter());

    drawSideFade();
    requestAnimationFrame(draw);
  }
  draw();

  // --- Reset handler scoped to canvas ---
  window.resetWaveParams = function (source) {
    if (source === "atc") atcParams = generateWaveParams(height);
    if (source === "spotify") spotifyParams = generateWaveParams(height);
  };
}
