// AudioMerger Studio - Web Audio Engine & Timeline UI

(function() {
  'use strict';

  // State
  let audioCtx = null;
  let tracks = [];
  let currentMode = 'overlap'; // 'overlap' or 'sequential'
  let isPlaying = false;
  let isLooping = false;
  let playbackStartTime = 0;
  let startOffsetSec = 0;
  let masterVolumeVal = 1.0;
  let zoomPixelsPerSec = 35;
  let crossfadeSec = 1.0;
  let isCrossfadeEnabled = true;
  let activeSourceNodes = [];
  let animFrameId = null;

  const COLORS = [
    '#6366f1', '#ec4899', '#10b981', '#f59e0b',
    '#8b5cf6', '#06b6d4', '#f43f5e', '#3b82f6'
  ];

  // DOM Elements
  const dropZone = document.getElementById('dropZone');
  const workspace = document.getElementById('workspace');
  const fileInput = document.getElementById('fileInput');
  const btnChooseFiles = document.getElementById('btnChooseFiles');
  const btnAddFiles = document.getElementById('btnAddFiles');
  const btnTryDemo = document.getElementById('btnTryDemo');
  const btnLoadDemo = document.getElementById('btnLoadDemo');
  const btnClearAll = document.getElementById('btnClearAll');
  const btnExport = document.getElementById('btnExport');

  const btnModeOverlap = document.getElementById('btnModeOverlap');
  const btnModeSequential = document.getElementById('btnModeSequential');
  const overlapActionsBar = document.getElementById('overlapActionsBar');
  const sequentialSettingsBar = document.getElementById('sequentialSettingsBar');
  const chkCrossfade = document.getElementById('chkCrossfade');
  const crossfadeSlider = document.getElementById('crossfadeSlider');
  const crossfadeVal = document.getElementById('crossfadeVal');

  const timeRuler = document.getElementById('timeRuler');
  const trackLanes = document.getElementById('trackLanes');
  const playhead = document.getElementById('playhead');
  const timelineViewport = document.getElementById('timelineViewport');
  const timelineDurationBadge = document.getElementById('timelineDurationBadge');
  const zoomSlider = document.getElementById('zoomSlider');
  const btnZoomIn = document.getElementById('btnZoomIn');
  const btnZoomOut = document.getElementById('btnZoomOut');

  const trackList = document.getElementById('trackList');
  const trackCount = document.getElementById('trackCount');

  const btnPlayPause = document.getElementById('btnPlayPause');
  const iconPlay = document.getElementById('iconPlay');
  const iconPause = document.getElementById('iconPause');
  const btnRewind = document.getElementById('btnRewind');
  const btnLoop = document.getElementById('btnLoop');
  const timeCurrent = document.getElementById('timeCurrent');
  const timeTotal = document.getElementById('timeTotal');
  const masterScrubber = document.getElementById('masterScrubber');
  const masterVolume = document.getElementById('masterVolume');

  // Export Modal
  const exportModal = document.getElementById('exportModal');
  const btnCloseModal = document.getElementById('btnCloseModal');
  const btnCancelExport = document.getElementById('btnCancelExport');
  const btnStartExport = document.getElementById('btnStartExport');
  const exportFilename = document.getElementById('exportFilename');
  const exportProgressWrap = document.getElementById('exportProgressWrap');
  const exportProgressBar = document.getElementById('exportProgressBar');
  const exportStatusText = document.getElementById('exportStatusText');

  // Alignment buttons
  const btnAlignZero = document.getElementById('btnAlignZero');
  const btnCascade2s = document.getElementById('btnCascade2s');
  const btnCascade4s = document.getElementById('btnCascade4s');
  const btnSnapSequential = document.getElementById('btnSnapSequential');

  // Init AudioContext
  function getAudioContext() {
    if (!audioCtx) {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      audioCtx = new AudioContextClass();
    }
    if (audioCtx.state === 'suspended') {
      audioCtx.resume();
    }
    return audioCtx;
  }

  // Format seconds to mm:ss.ms
  function formatTime(sec) {
    if (isNaN(sec) || sec < 0) sec = 0;
    const mins = Math.floor(sec / 60);
    const s = Math.floor(sec % 60);
    const ms = Math.floor((sec % 1) * 10);
    return `${String(mins).padStart(2, '0')}:${String(s).padStart(2, '0')}.${ms}`;
  }

  function formatShort(sec) {
    if (sec < 60) return `${sec.toFixed(1)}s`;
    const m = Math.floor(sec / 60);
    const s = Math.floor(sec % 60);
    return `${m}m ${s}s`;
  }

  // Event Listeners for Mode Switching
  btnModeOverlap.addEventListener('click', () => setMode('overlap'));
  btnModeSequential.addEventListener('click', () => setMode('sequential'));

  function setMode(mode) {
    currentMode = mode;
    btnModeOverlap.classList.toggle('active', mode === 'overlap');
    btnModeSequential.classList.toggle('active', mode === 'sequential');
    overlapActionsBar.style.display = mode === 'overlap' ? 'flex' : 'none';
    sequentialSettingsBar.style.display = mode === 'sequential' ? 'flex' : 'none';

    if (mode === 'sequential') {
      recomputeSequentialOffsets();
    }

    if (isPlaying) stopPlayback();
    renderAll();
  }

  function recomputeSequentialOffsets() {
    let cursor = 0;
    tracks.forEach((t, i) => {
      const trimmedDur = Math.max(0.1, t.trimEnd - t.trimStart);
      const effectiveCrossfade = (i > 0 && isCrossfadeEnabled) ? Math.min(crossfadeSec, trimmedDur * 0.4) : 0;
      t.offsetTime = Math.max(0, cursor - effectiveCrossfade);
      cursor = t.offsetTime + trimmedDur;
    });
  }

  // Crossfade controls
  chkCrossfade.addEventListener('change', () => {
    isCrossfadeEnabled = chkCrossfade.checked;
    if (currentMode === 'sequential') recomputeSequentialOffsets();
    renderAll();
  });

  crossfadeSlider.addEventListener('input', (e) => {
    crossfadeSec = parseFloat(e.target.value);
    crossfadeVal.textContent = `${crossfadeSec.toFixed(1)}s`;
    if (currentMode === 'sequential') recomputeSequentialOffsets();
    renderAll();
  });

  // Zoom controls
  zoomSlider.addEventListener('input', (e) => {
    zoomPixelsPerSec = parseInt(e.target.value, 10);
    renderTimeline();
  });
  btnZoomIn.addEventListener('click', () => {
    zoomPixelsPerSec = Math.min(80, zoomPixelsPerSec + 5);
    zoomSlider.value = zoomPixelsPerSec;
    renderTimeline();
  });
  btnZoomOut.addEventListener('click', () => {
    zoomPixelsPerSec = Math.max(15, zoomPixelsPerSec - 5);
    zoomSlider.value = zoomPixelsPerSec;
    renderTimeline();
  });

  // Alignment helpers
  btnAlignZero.addEventListener('click', () => {
    tracks.forEach(t => t.offsetTime = 0);
    renderAll();
  });
  btnCascade2s.addEventListener('click', () => {
    tracks.forEach((t, i) => t.offsetTime = i * 2.0);
    renderAll();
  });
  btnCascade4s.addEventListener('click', () => {
    tracks.forEach((t, i) => t.offsetTime = i * 4.0);
    renderAll();
  });
  btnSnapSequential.addEventListener('click', () => {
    let cursor = 0;
    tracks.forEach(t => {
      t.offsetTime = cursor;
      cursor += Math.max(0.1, t.trimEnd - t.trimStart);
    });
    renderAll();
  });

  // File loading
  btnChooseFiles.addEventListener('click', () => fileInput.click());
  btnAddFiles.addEventListener('click', () => fileInput.click());
  fileInput.addEventListener('change', (e) => {
    if (e.target.files.length) handleFiles(Array.from(e.target.files));
    fileInput.value = '';
  });

  // Drag & drop
  ['dragenter', 'dragover'].forEach(name => {
    document.addEventListener(name, (e) => {
      e.preventDefault();
      dropZone.querySelector('.drop-card')?.classList.add('drag-over');
    });
  });
  ['dragleave', 'drop'].forEach(name => {
    document.addEventListener(name, (e) => {
      e.preventDefault();
      dropZone.querySelector('.drop-card')?.classList.remove('drag-over');
    });
  });
  document.addEventListener('drop', (e) => {
    if (e.dataTransfer.files.length) {
      handleFiles(Array.from(e.dataTransfer.files));
    }
  });

  async function handleFiles(files) {
    const ctx = getAudioContext();
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      try {
        const arrayBuf = await file.arrayBuffer();
        const audioBuf = await ctx.decodeAudioData(arrayBuf);
        addTrackFromBuffer(file.name, audioBuf);
      } catch (err) {
        console.error('Failed to decode audio:', file.name, err);
      }
    }
    renderAll();
  }

  function addTrackFromBuffer(name, buffer, customOffset = null) {
    const color = COLORS[tracks.length % COLORS.length];
    const dur = buffer.duration;
    let initialOffset = 0;

    if (customOffset !== null) {
      initialOffset = customOffset;
    } else if (currentMode === 'sequential') {
      const last = tracks[tracks.length - 1];
      initialOffset = last ? last.offsetTime + (last.trimEnd - last.trimStart) : 0;
    }

    const track = {
      id: 'track_' + Math.random().toString(36).substr(2, 9),
      name: name.replace(/\.[^/.]+$/, ''),
      format: name.split('.').pop().toUpperCase(),
      buffer: buffer,
      duration: dur,
      trimStart: 0,
      trimEnd: dur,
      offsetTime: initialOffset,
      volume: 1.0,
      isMuted: false,
      isSoloed: false,
      fadeIn: 0,
      fadeOut: 0,
      color: color,
      samples: computeWaveformSamples(buffer, 80)
    };

    tracks.push(track);
  }

  function computeWaveformSamples(buffer, targetBars = 80) {
    const raw = buffer.getChannelData(0);
    const step = Math.floor(raw.length / targetBars);
    const result = [];
    let max = 0.001;

    for (let i = 0; i < targetBars; i++) {
      let sum = 0;
      const start = i * step;
      for (let j = 0; j < step; j += 10) {
        sum += Math.abs(raw[start + j] || 0);
      }
      const avg = sum / (step / 10);
      if (avg > max) max = avg;
      result.push(avg);
    }

    return result.map(v => Math.max(0.1, Math.min(1.0, v / max)));
  }

  // Synthesize Demo Tracks (Beat, Bass, Melody)
  btnTryDemo.addEventListener('click', loadDemoStems);
  btnLoadDemo.addEventListener('click', loadDemoStems);

  async function loadDemoStems() {
    const ctx = getAudioContext();
    const dur = 12.0;
    const sampleRate = ctx.sampleRate;
    const numSamples = Math.floor(sampleRate * dur);

    // 1. Drum Beat
    const drumBuf = ctx.createBuffer(2, numSamples, sampleRate);
    const dL = drumBuf.getChannelData(0);
    const dR = drumBuf.getChannelData(1);
    const beatSec = 0.5;

    for (let i = 0; i < numSamples; i++) {
      const t = i / sampleRate;
      const bTime = t % beatSec;
      const measure = Math.floor(t / beatSec) % 4;
      let s = 0;

      // Kick on 0 and 2
      if ((measure === 0 || measure === 2) && bTime < 0.18) {
        const freq = 130 * Math.exp(-bTime * 25) + 45;
        s += Math.sin(2 * Math.PI * freq * bTime) * Math.exp(-bTime * 14) * 0.7;
      }
      // Snare on 1 and 3
      if ((measure === 1 || measure === 3) && bTime < 0.22) {
        s += (Math.random() * 2 - 1) * Math.exp(-bTime * 18) * 0.4;
      }
      // Hi-hat
      const eighth = t % (beatSec / 2);
      if (eighth < 0.05) {
        s += (Math.random() * 2 - 1) * Math.exp(-eighth * 60) * 0.15;
      }
      dL[i] = s;
      dR[i] = s;
    }

    // 2. Bassline
    const bassBuf = ctx.createBuffer(2, numSamples, sampleRate);
    const bL = bassBuf.getChannelData(0);
    const bR = bassBuf.getChannelData(1);
    const bassNotes = [65.41, 65.41, 77.78, 87.31, 98.00, 87.31, 77.78, 65.41];

    for (let i = 0; i < numSamples; i++) {
      const t = i / sampleRate;
      const idx = Math.floor(t / 0.5) % bassNotes.count || Math.floor(t / 0.5) % 8;
      const nTime = t % 0.5;
      const freq = bassNotes[idx];
      const env = Math.exp(-nTime * 3.5);
      const s = Math.sin(2 * Math.PI * freq * nTime) * env * 0.5;
      bL[i] = s;
      bR[i] = s;
    }

    // 3. Arpeggiated Synth Melody
    const melBuf = ctx.createBuffer(2, numSamples, sampleRate);
    const mL = melBuf.getChannelData(0);
    const mR = melBuf.getChannelData(1);
    const chimes = [261.63, 311.13, 392.00, 466.16, 523.25, 466.16, 392.00, 311.13];

    for (let i = 0; i < numSamples; i++) {
      const t = i / sampleRate;
      const idx = Math.floor(t / 0.25) % 8;
      const nTime = t % 0.25;
      const freq = chimes[idx];
      const env = Math.exp(-nTime * 7);
      const s = Math.sin(2 * Math.PI * freq * nTime) * env * 0.4;
      const pan = Math.sin(2 * Math.PI * 0.5 * t);
      mL[i] = s * (1 - pan * 0.3);
      mR[i] = s * (1 + pan * 0.3);
    }

    // Add with staggering offsets so they overlap beautifully
    tracks = [];
    addTrackFromBuffer('1_Rhythm_Drums.wav', drumBuf, 0.0);
    addTrackFromBuffer('2_Groove_Bass.wav', bassBuf, 2.0); // Starts at 2s, overlapping drums
    addTrackFromBuffer('3_Synth_Melody.wav', melBuf, 4.0); // Starts at 4s, overlapping drums & bass

    renderAll();
  }

  // Clear tracks
  btnClearAll.addEventListener('click', () => {
    if (isPlaying) stopPlayback();
    tracks = [];
    renderAll();
  });

  // Calculate Total Duration
  function getTotalDuration() {
    if (!tracks.length) return 0;
    if (currentMode === 'sequential') {
      const last = tracks[tracks.length - 1];
      return Math.max(0.1, last.offsetTime + (last.trimEnd - last.trimStart));
    } else {
      let maxEnd = 0;
      tracks.forEach(t => {
        const end = t.offsetTime + (t.trimEnd - t.trimStart);
        if (end > maxEnd) maxEnd = end;
      });
      return Math.max(0.1, maxEnd);
    }
  }

  // Main Render Routine
  function renderAll() {
    const hasTracks = tracks.length > 0;
    dropZone.style.display = hasTracks ? 'none' : 'flex';
    workspace.style.display = hasTracks ? 'flex' : 'none';
    btnClearAll.style.display = hasTracks ? 'inline-flex' : 'none';
    btnExport.disabled = !hasTracks;
    trackCount.textContent = tracks.length;

    const totalDur = getTotalDuration();
    timelineDurationBadge.textContent = formatTime(totalDur);
    timeTotal.textContent = formatTime(totalDur);
    masterScrubber.max = totalDur;

    renderTimeline();
    renderTrackList();
  }

  // Render Visual Timeline
  function renderTimeline() {
    const totalDur = Math.max(5.0, getTotalDuration());
    const timelineWidth = Math.max(800, totalDur * zoomPixelsPerSec + 120);

    timeRuler.style.width = `${timelineWidth}px`;
    trackLanes.style.width = `${timelineWidth}px`;

    // Render Ruler Ticks
    timeRuler.innerHTML = '';
    const step = zoomPixelsPerSec > 35 ? 1 : (zoomPixelsPerSec > 20 ? 2 : 5);

    for (let s = 0; s <= totalDur + 5; s += step) {
      const x = s * zoomPixelsPerSec;
      const isMajor = s % 5 === 0;

      const tick = document.createElement('div');
      tick.className = `ruler-tick ${isMajor ? 'major' : ''}`;
      tick.style.left = `${x}px`;
      timeRuler.appendChild(tick);

      if (isMajor) {
        const lbl = document.createElement('span');
        lbl.className = 'ruler-label';
        lbl.textContent = formatShort(s);
        lbl.style.left = `${x}px`;
        timeRuler.appendChild(lbl);
      }
    }

    // Ruler click seeking
    timeRuler.onclick = (e) => {
      const rect = timeRuler.getBoundingClientRect();
      const clickX = e.clientX - rect.left;
      const seekSec = Math.max(0, Math.min(totalDur, clickX / zoomPixelsPerSec));
      seekTo(seekSec);
    };

    // Render Track Lanes & Clips
    trackLanes.innerHTML = '';
    tracks.forEach((track, idx) => {
      const lane = document.createElement('div');
      lane.className = 'track-lane';

      const trimmedDur = Math.max(0.1, track.trimEnd - track.trimStart);
      const clipLeft = track.offsetTime * zoomPixelsPerSec;
      const clipWidth = Math.max(24, trimmedDur * zoomPixelsPerSec);

      const clip = document.createElement('div');
      clip.className = 'timeline-clip';
      clip.style.left = `${clipLeft}px`;
      clip.style.width = `${clipWidth}px`;
      clip.style.backgroundColor = track.color;

      clip.innerHTML = `
        <span class="clip-title">${track.name}</span>
        <span class="clip-meta">${formatShort(trimmedDur)} @ ${formatTime(track.offsetTime)}</span>
      `;

      // Drag clip in Overlap mode
      if (currentMode === 'overlap') {
        let isDragging = false;
        let startX = 0;
        let origOffset = 0;

        clip.addEventListener('mousedown', (e) => {
          isDragging = true;
          startX = e.clientX;
          origOffset = track.offsetTime;
          document.body.style.cursor = 'grabbing';

          const onMouseMove = (ev) => {
            if (!isDragging) return;
            const deltaPx = ev.clientX - startX;
            const deltaSec = deltaPx / zoomPixelsPerSec;
            track.offsetTime = Math.max(0, origOffset + deltaSec);
            renderAll();
          };

          const onMouseUp = () => {
            isDragging = false;
            document.body.style.cursor = '';
            window.removeEventListener('mousemove', onMouseMove);
            window.removeEventListener('mouseup', onMouseUp);
          };

          window.addEventListener('mousemove', onMouseMove);
          window.addEventListener('mouseup', onMouseUp);
        });
      }

      lane.appendChild(clip);
      trackLanes.appendChild(lane);
    });

    updatePlayheadPosition();
  }

  function updatePlayheadPosition() {
    const curTime = getCurrentPlaybackTime();
    const x = curTime * zoomPixelsPerSec;
    playhead.style.left = `${x}px`;
    timeCurrent.textContent = formatTime(curTime);
    masterScrubber.value = curTime;
  }

  // Render Track List
  function renderTrackList() {
    trackList.innerHTML = '';

    tracks.forEach((track, idx) => {
      const card = document.createElement('div');
      card.className = 'track-card';

      const trimmedDur = Math.max(0.01, track.trimEnd - track.trimStart);

      card.innerHTML = `
        <div class="track-card-header">
          <div class="track-index-badge" style="background-color: ${track.color};">${idx + 1}</div>
          <div class="track-name-wrap">
            <div class="track-name-row">
              <span class="track-name">${track.name}</span>
              <span class="format-pill">${track.format}</span>
            </div>
            <span class="track-dur-label">Duration: ${formatShort(trimmedDur)} (orig: ${formatShort(track.duration)})</span>
          </div>

          <div class="track-header-actions">
            ${currentMode === 'sequential' ? `
              <button class="btn btn-xs btn-move-up" ${idx === 0 ? 'disabled' : ''}>▲</button>
              <button class="btn btn-xs btn-move-down" ${idx === tracks.length - 1 ? 'disabled' : ''}>▼</button>
            ` : ''}
            <button class="btn-mute ${track.isMuted ? 'active' : ''}" title="Mute track">M</button>
            <button class="btn-solo ${track.isSoloed ? 'active' : ''}" title="Solo track">S</button>
            <button class="btn btn-icon btn-danger btn-xs btn-delete" title="Remove track">
              <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
            </button>
          </div>
        </div>

        <!-- Waveform Canvas -->
        <div class="waveform-canvas-container">
          <canvas class="waveform-canvas" width="600" height="36"></canvas>
        </div>

        <!-- Trim Controls -->
        <div class="track-trim-row">
          <div class="trim-group">
            <span>Trim Start:</span>
            <input type="range" class="trim-start-range" min="0" max="${Math.max(0, track.trimEnd - 0.2)}" step="0.1" value="${track.trimStart}">
            <span class="trim-time">${formatTime(track.trimStart)}</span>
          </div>
          <div class="trim-group">
            <span>Trim End:</span>
            <input type="range" class="trim-end-range" min="${track.trimStart + 0.2}" max="${track.duration}" step="0.1" value="${track.trimEnd}">
            <span class="trim-time">${formatTime(track.trimEnd)}</span>
          </div>
        </div>

        <!-- Volume & Mode-specific row -->
        <div class="track-controls-row">
          <div class="ctrl-item">
            <span>Volume:</span>
            <input type="range" class="vol-range" min="0" max="2" step="0.05" value="${track.volume}">
            <span>${Math.round(track.volume * 100)}%</span>
          </div>

          ${currentMode === 'overlap' ? `
            <div class="ctrl-item">
              <span>Start Offset:</span>
              <input type="number" class="offset-num" min="0" max="300" step="0.25" value="${track.offsetTime.toFixed(2)}">
              <span>sec</span>
            </div>
            <div class="ctrl-item">
              <span>Fade In:</span>
              <input type="number" class="fadein-num" min="0" max="5" step="0.5" value="${track.fadeIn}">
              <span>s</span>
            </div>
            <div class="ctrl-item">
              <span>Fade Out:</span>
              <input type="number" class="fadeout-num" min="0" max="5" step="0.5" value="${track.fadeOut}">
              <span>s</span>
            </div>
          ` : ''}
        </div>
      `;

      // Draw waveform on canvas
      const canvas = card.querySelector('.waveform-canvas');
      drawWaveform(canvas, track);

      // Event handlers
      card.querySelector('.btn-mute').onclick = () => {
        track.isMuted = !track.isMuted;
        renderAll();
      };
      card.querySelector('.btn-solo').onclick = () => {
        track.isSoloed = !track.isSoloed;
        renderAll();
      };
      card.querySelector('.btn-delete').onclick = () => {
        tracks.splice(idx, 1);
        renderAll();
      };

      if (currentMode === 'sequential') {
        const btnUp = card.querySelector('.btn-move-up');
        if (btnUp) btnUp.onclick = () => {
          if (idx > 0) {
            const temp = tracks[idx];
            tracks[idx] = tracks[idx - 1];
            tracks[idx - 1] = temp;
            recomputeSequentialOffsets();
            renderAll();
          }
        };
        const btnDown = card.querySelector('.btn-move-down');
        if (btnDown) btnDown.onclick = () => {
          if (idx < tracks.length - 1) {
            const temp = tracks[idx];
            tracks[idx] = tracks[idx + 1];
            tracks[idx + 1] = temp;
            recomputeSequentialOffsets();
            renderAll();
          }
        };
      }

      // Trim changes
      const startRange = card.querySelector('.trim-start-range');
      const endRange = card.querySelector('.trim-end-range');
      startRange.oninput = (e) => {
        track.trimStart = parseFloat(e.target.value);
        if (currentMode === 'sequential') recomputeSequentialOffsets();
        renderAll();
      };
      endRange.oninput = (e) => {
        track.trimEnd = parseFloat(e.target.value);
        if (currentMode === 'sequential') recomputeSequentialOffsets();
        renderAll();
      };

      // Volume change
      card.querySelector('.vol-range').oninput = (e) => {
        track.volume = parseFloat(e.target.value);
        renderAll();
      };

      if (currentMode === 'overlap') {
        card.querySelector('.offset-num').onchange = (e) => {
          track.offsetTime = Math.max(0, parseFloat(e.target.value) || 0);
          renderAll();
        };
        card.querySelector('.fadein-num').onchange = (e) => {
          track.fadeIn = Math.max(0, parseFloat(e.target.value) || 0);
          renderAll();
        };
        card.querySelector('.fadeout-num').onchange = (e) => {
          track.fadeOut = Math.max(0, parseFloat(e.target.value) || 0);
          renderAll();
        };
      }

      trackList.appendChild(card);
    });
  }

  function drawWaveform(canvas, track) {
    const ctx = canvas.getContext('2d');
    const w = canvas.width;
    const h = canvas.height;
    ctx.clearRect(0, 0, w, h);

    const samples = track.samples;
    const barWidth = Math.max(2, (w / samples.length) - 1);
    const startFrac = track.trimStart / track.duration;
    const endFrac = track.trimEnd / track.duration;

    for (let i = 0; i < samples.length; i++) {
      const frac = i / samples.length;
      const isInside = frac >= startFrac && frac <= endFrac;
      const barH = Math.max(4, samples[i] * h * 0.85);
      const y = (h - barH) / 2;
      const x = i * (w / samples.length);

      ctx.fillStyle = isInside ? track.color : 'rgba(255, 255, 255, 0.15)';
      ctx.fillRect(x, y, barWidth, barH);
    }
  }

  // Playback Engine
  function getCurrentPlaybackTime() {
    if (!isPlaying) return startOffsetSec;
    const elapsed = audioCtx.currentTime - playbackStartTime;
    return startOffsetSec + elapsed;
  }

  btnPlayPause.addEventListener('click', togglePlayback);
  btnRewind.addEventListener('click', () => seekTo(0));
  btnLoop.addEventListener('click', () => {
    isLooping = !isLooping;
    btnLoop.classList.toggle('active', isLooping);
  });

  masterScrubber.addEventListener('input', (e) => {
    seekTo(parseFloat(e.target.value));
  });

  masterVolume.addEventListener('input', (e) => {
    masterVolumeVal = parseFloat(e.target.value);
  });

  function togglePlayback() {
    if (isPlaying) {
      stopPlayback();
    } else {
      startPlayback();
    }
  }

  function startPlayback() {
    const ctx = getAudioContext();
    const totalDur = getTotalDuration();
    if (startOffsetSec >= totalDur - 0.05) startOffsetSec = 0;

    stopActiveNodes();

    playbackStartTime = ctx.currentTime;
    const hasSolo = tracks.some(t => t.isSoloed);

    tracks.forEach(track => {
      let effVol = hasSolo ? (track.isSoloed ? track.volume : 0) : (track.isMuted ? 0 : track.volume);
      effVol *= masterVolumeVal;

      const trimmedDur = track.trimEnd - track.trimStart;
      const trackStart = track.offsetTime;
      const trackEnd = trackStart + trimmedDur;

      // Check if this track should play during the remaining timeline
      if (startOffsetSec < trackEnd) {
        const offsetInTrack = Math.max(0, startOffsetSec - trackStart);
        const delayUntilStart = Math.max(0, trackStart - startOffsetSec);

        const source = ctx.createBufferSource();
        source.buffer = track.buffer;

        const gainNode = ctx.createGain();
        gainNode.gain.setValueAtTime(effVol, ctx.currentTime);

        source.connect(gainNode);
        gainNode.connect(ctx.destination);

        const bufferOffset = track.trimStart + offsetInTrack;
        const playDuration = Math.max(0, trimmedDur - offsetInTrack);

        source.start(ctx.currentTime + delayUntilStart, bufferOffset, playDuration);
        activeSourceNodes.push(source);
      }
    });

    isPlaying = true;
    iconPlay.style.display = 'none';
    iconPause.style.display = 'block';

    startAnimationLoop();
  }

  function stopPlayback() {
    startOffsetSec = getCurrentPlaybackTime();
    stopActiveNodes();
    isPlaying = false;
    iconPlay.style.display = 'block';
    iconPause.style.display = 'none';
    if (animFrameId) cancelAnimationFrame(animFrameId);
  }

  function stopActiveNodes() {
    activeSourceNodes.forEach(node => {
      try { node.stop(); } catch (e) {}
    });
    activeSourceNodes = [];
  }

  function seekTo(sec) {
    const wasPlaying = isPlaying;
    if (isPlaying) stopPlayback();
    startOffsetSec = sec;
    updatePlayheadPosition();
    if (wasPlaying) startPlayback();
  }

  function startAnimationLoop() {
    function loop() {
      if (!isPlaying) return;
      const curTime = getCurrentPlaybackTime();
      const totalDur = getTotalDuration();

      if (curTime >= totalDur) {
        if (isLooping) {
          seekTo(0);
          startPlayback();
          return;
        } else {
          stopPlayback();
          seekTo(0);
          return;
        }
      }

      updatePlayheadPosition();
      animFrameId = requestAnimationFrame(loop);
    }
    animFrameId = requestAnimationFrame(loop);
  }

  // Keyboard shortcut Space to Play/Pause
  window.addEventListener('keydown', (e) => {
    if (e.code === 'Space' && e.target.tagName !== 'INPUT') {
      e.preventDefault();
      togglePlayback();
    }
  });

  // Export Engine (WAV Rendering)
  btnExport.addEventListener('click', () => {
    exportModal.style.display = 'flex';
    exportProgressWrap.style.display = 'none';
    exportProgressBar.style.width = '0%';
  });
  btnCloseModal.addEventListener('click', () => exportModal.style.display = 'none');
  btnCancelExport.addEventListener('click', () => exportModal.style.display = 'none');

  btnStartExport.addEventListener('click', async () => {
    exportProgressWrap.style.display = 'block';
    exportProgressBar.style.width = '20%';
    exportStatusText.textContent = 'Preparing render engine...';

    const totalDur = getTotalDuration();
    const sampleRate = 44100;
    const offlineCtx = new OfflineAudioContext(2, Math.ceil(totalDur * sampleRate), sampleRate);

    const hasSolo = tracks.some(t => t.isSoloed);

    tracks.forEach(track => {
      let effVol = hasSolo ? (track.isSoloed ? track.volume : 0) : (track.isMuted ? 0 : track.volume);
      effVol *= masterVolumeVal;

      const trimmedDur = track.trimEnd - track.trimStart;
      const source = offlineCtx.createBufferSource();
      source.buffer = track.buffer;

      const gainNode = offlineCtx.createGain();

      // Fade In & Fade Out automation
      const startTime = track.offsetTime;
      gainNode.gain.setValueAtTime(0, startTime);
      if (track.fadeIn > 0) {
        gainNode.gain.linearRampToValueAtTime(effVol, startTime + track.fadeIn);
      } else {
        gainNode.gain.setValueAtTime(effVol, startTime);
      }

      if (track.fadeOut > 0) {
        const fadeStart = startTime + trimmedDur - track.fadeOut;
        gainNode.gain.setValueAtTime(effVol, fadeStart);
        gainNode.gain.linearRampToValueAtTime(0, startTime + trimmedDur);
      }

      source.connect(gainNode);
      gainNode.connect(offlineCtx.destination);
      source.start(startTime, track.trimStart, trimmedDur);
    });

    exportProgressBar.style.width = '60%';
    exportStatusText.textContent = 'Synthesizing & mixing tracks...';

    const renderedBuffer = await offlineCtx.startRendering();

    exportProgressBar.style.width = '85%';
    exportStatusText.textContent = 'Encoding lossless WAV file...';

    const wavBlob = audioBufferToWavBlob(renderedBuffer);

    exportProgressBar.style.width = '100%';
    exportStatusText.textContent = 'Export complete! Downloading...';

    // Trigger download
    const filename = (exportFilename.value.trim() || 'Merged_Audio') + '.wav';
    const link = document.createElement('a');
    link.href = URL.createObjectURL(wavBlob);
    link.download = filename;
    link.click();

    setTimeout(() => {
      exportModal.style.display = 'none';
    }, 1200);
  });

  // Convert AudioBuffer to 16-bit PCM WAV Blob
  function audioBufferToWavBlob(buffer) {
    const numChannels = buffer.numberOfChannels;
    const sampleRate = buffer.sampleRate;
    const format = 1; // PCM
    const bitDepth = 16;

    const left = buffer.getChannelData(0);
    const right = numChannels > 1 ? buffer.getChannelData(1) : left;
    const length = left.length * numChannels * 2;

    const wavBuffer = new ArrayBuffer(44 + length);
    const view = new DataView(wavBuffer);

    // RIFF chunk descriptor
    writeString(view, 0, 'RIFF');
    view.setUint32(4, 36 + length, true);
    writeString(view, 8, 'WAVE');

    // fmt sub-chunk
    writeString(view, 12, 'fmt ');
    view.setUint32(16, 16, true);
    view.setUint16(20, format, true);
    view.setUint16(22, numChannels, true);
    view.setUint32(24, sampleRate, true);
    view.setUint32(28, sampleRate * numChannels * (bitDepth / 8), true);
    view.setUint16(32, numChannels * (bitDepth / 8), true);
    view.setUint16(34, bitDepth, true);

    // data sub-chunk
    writeString(view, 36, 'data');
    view.setUint32(40, length, true);

    // Interleave left and right samples
    let offset = 44;
    for (let i = 0; i < left.length; i++) {
      let sampleL = Math.max(-1, Math.min(1, left[i]));
      view.setInt16(offset, sampleL < 0 ? sampleL * 0x8000 : sampleL * 0x7FFF, true);
      offset += 2;

      let sampleR = Math.max(-1, Math.min(1, right[i]));
      view.setInt16(offset, sampleR < 0 ? sampleR * 0x8000 : sampleR * 0x7FFF, true);
      offset += 2;
    }

    return new Blob([view], { type: 'audio/wav' });
  }

  function writeString(view, offset, string) {
    for (let i = 0; i < string.length; i++) {
      view.setUint8(offset + i, string.charCodeAt(i));
    }
  }

})();
