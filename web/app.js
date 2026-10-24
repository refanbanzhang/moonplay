const AUDIO_EXTENSIONS = new Set(["mp3", "wav", "m4a", "aac", "aiff", "aif", "flac", "caf", "ogg", "opus"]);
const MIME_TYPES = new Map([
  ["mp3", "audio/mpeg"],
  ["wav", "audio/wav"],
  ["m4a", "audio/mp4"],
  ["aac", "audio/aac"],
  ["aiff", "audio/aiff"],
  ["aif", "audio/aiff"],
  ["flac", "audio/flac"],
  ["caf", "audio/x-caf"],
  ["ogg", "audio/ogg"],
  ["opus", "audio/ogg"],
]);
const state = {
  tracks: [],
  activeId: null,
  objectUrls: new Set(),
  rows: new Map(),
  audioContext: null,
  stop: { on: false, time: "23:00" },
  stopDue: 0,
  stopTimer: 0,
};

const STORAGE_NAME = "moonplay";
const STORAGE_VERSION = 1;
const STORAGE_STORE = "library";
const STORAGE_KEY = "current";
const STOP_KEY = "moonplay-stop";
const musicInput = document.querySelector("[data-music-input]");
const trackList = document.querySelector("[data-track-list]");
const statusMessage = document.querySelector("[data-status]");
const errorMessage = document.querySelector("[data-error]");
const settingsDialog = document.querySelector("[data-settings]");
const stopToggle = document.querySelector("[data-stop-on]");
const stopTimeInput = document.querySelector("[data-stop-time]");
const stopNote = document.querySelector("[data-stop-note]");
const LOG_PREFIX = "[Moonplay]";
const missing = [
  ["musicInput", musicInput],
  ["trackList", trackList],
  ["statusMessage", statusMessage],
  ["errorMessage", errorMessage],
  ["settingsDialog", settingsDialog],
  ["stopToggle", stopToggle],
  ["stopTimeInput", stopTimeInput],
  ["stopNote", stopNote],
].flatMap(([name, node]) => (node ? [] : [name]));

console.info(LOG_PREFIX, "启动", { script: import.meta.url, missing });
if (missing.length) throw new Error(`页面节点缺失: ${missing.join(", ")}`);

document.addEventListener("click", (event) => {
  const action = event.target.closest("[data-action]")?.dataset.action;
  if (action === "choose-music") chooseMusic();
  if (action === "settings") openSettings();
});

settingsDialog.addEventListener("click", (event) => {
  if (event.target === settingsDialog) settingsDialog.close();
});

stopToggle.addEventListener("change", () => {
  state.stop.on = stopToggle.checked;
  state.stopDue = 0;
  try {
    persistStop();
  } catch (error) {
    showError(error.message);
  }
  syncStop();
});

stopTimeInput.addEventListener("change", () => {
  let time;
  try {
    time = parseStopTime(stopTimeInput.value);
  } catch (error) {
    stopTimeInput.value = state.stop.time;
    showError(error.message);
    return;
  }
  state.stop.time = time;
  state.stopDue = 0;
  try {
    persistStop();
  } catch (error) {
    showError(error.message);
  }
  syncStop();
});

document.addEventListener("visibilitychange", () => {
  console.info(LOG_PREFIX, "页面可见性变化", {
    visibilityState: document.visibilityState,
    hidden: document.hidden,
    activeTracks: state.tracks.filter((track) => !track.audio.paused).map((track) => track.title),
    audioContext: state.audioContext?.state || "未创建",
  });
  if (document.visibilityState === "visible") syncStop();
});

window.addEventListener("pagehide", (event) => {
  console.info(LOG_PREFIX, "页面隐藏", {
    persisted: event.persisted,
    activeTracks: state.tracks.filter((track) => !track.audio.paused).map((track) => track.title),
    audioContext: state.audioContext?.state || "未创建",
  });
});

musicInput.addEventListener("change", async (event) => {
  const files = Array.from(event.target.files || []);
  if (!files.length) return;
  const append = state.tracks.length > 0;
  console.info(LOG_PREFIX, "文件选择完成", { count: files.length, append });
  try {
    await loadFiles(files, { append });
  } catch (error) {
    reportLoadError(error);
  } finally {
    musicInput.value = "";
  }
});

function chooseMusic() {
  clearError();
  clearStatus();
  console.info(LOG_PREFIX, "开始选择音乐文件");
  musicInput.click();
}

async function loadFiles(files, { persist = true, activeTitle = "", append = false } = {}) {
  setStatus("正在准备音频列表…");
  const audioFiles = files
    .filter((file) => AUDIO_EXTENSIONS.has(getExtension(file.name)))
    .sort((first, second) => first.name.localeCompare(second.name, undefined, { sensitivity: "base" }));
  console.info(LOG_PREFIX, "音频文件筛选完成", {
    total: files.length,
    supported: audioFiles.length,
    append,
  });

  if (audioFiles.length === 0) {
    clearStatus();
    throw new Error("没有找到支持的音频文件");
  }

  if (append && state.tracks.length > 0) {
    const seen = new Set(state.tracks.map((track) => trackKey(track.file)));
    const added = audioFiles.filter((file) => !seen.has(trackKey(file)));
    for (const file of added) {
      state.tracks.push(createTrack(file));
    }
    state.tracks.sort((first, second) =>
      first.title.localeCompare(second.title, undefined, { sensitivity: "base" }),
    );
    console.info(LOG_PREFIX, "追加音乐完成", { added: added.length, total: state.tracks.length });
  } else {
    releaseTracks();
    state.tracks = audioFiles.map(createTrack);
    state.activeId =
      state.tracks.find((track) => track.title === activeTitle && track.canPlay)?.id ||
      state.tracks.find((track) => track.canPlay)?.id ||
      state.tracks[0]?.id ||
      null;
  }

  renderTracks();
  if (persist) {
    await saveLibrary(state.tracks.map((track) => track.file), state.activeId);
  }
  clearStatus();
}

async function restoreLibrary() {
  const saved = await readLibrary();
  if (!saved?.files?.length) return;

  console.info(LOG_PREFIX, "正在恢复本地音乐", { count: saved.files.length });
  await loadFiles(saved.files, {
    persist: false,
    activeTitle: saved.activeTitle,
  });
}

function openStorage() {
  return new Promise((resolve, reject) => {
    if (!("indexedDB" in window)) {
      reject(new Error("当前浏览器不支持本地音乐存储"));
      return;
    }

    const request = indexedDB.open(STORAGE_NAME, STORAGE_VERSION);
    request.onupgradeneeded = () => {
      request.result.createObjectStore(STORAGE_STORE);
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error || new Error("打开本地音乐存储失败"));
  });
}

async function saveLibrary(files, activeId = state.activeId) {
  const activeTrack = state.tracks.find((track) => track.id === activeId);
  const database = await openStorage();
  try {
    await new Promise((resolve, reject) => {
      const transaction = database.transaction(STORAGE_STORE, "readwrite");
      transaction.objectStore(STORAGE_STORE).put(
        {
          files,
          activeTitle: activeTrack?.title || "",
        },
        STORAGE_KEY,
      );
      transaction.oncomplete = resolve;
      transaction.onerror = () => reject(transaction.error || new Error("保存本地音乐失败"));
      transaction.onabort = () => reject(transaction.error || new Error("保存本地音乐失败"));
    });
  } finally {
    database.close();
  }
}

async function readLibrary() {
  const database = await openStorage();
  try {
    return await new Promise((resolve, reject) => {
      const request = database
        .transaction(STORAGE_STORE, "readonly")
        .objectStore(STORAGE_STORE)
        .get(STORAGE_KEY);
      request.onsuccess = () => resolve(request.result || null);
      request.onerror = () => reject(request.error || new Error("读取本地音乐失败"));
    });
  } finally {
    database.close();
  }
}

function createTrack(file) {
  const extension = getExtension(file.name);
  const url = URL.createObjectURL(file);
  const audio = new Audio(url);
  const track = {
    id: createId(),
    file,
    audio,
    url,
    extension,
    title: file.name,
    metadata: describeFile(file, extension),
    canPlay: true,
    error: false,
    volume: 1,
    sourceNode: null,
    gainNode: null,
  };

  state.objectUrls.add(url);
  audio.preload = "metadata";
  audio.loop = true;
  audio.volume = track.volume;
  audio.addEventListener("error", () => {
    track.canPlay = false;
    track.error = true;
    updateTrackRow(track);
  });
  audio.addEventListener("play", () => {
    updateTrackRow(track);
  });
  audio.addEventListener("pause", () => {
    updateTrackRow(track);
    console.info(LOG_PREFIX, "音频暂停", {
      track: track.title,
      currentTime: Number(track.audio.currentTime.toFixed(2)),
      readyState: track.audio.readyState,
      networkState: track.audio.networkState,
      visibilityState: document.visibilityState,
      audioContext: state.audioContext?.state || "未创建",
    });
  });
  audio.addEventListener("waiting", () => {
    console.warn(LOG_PREFIX, "音频等待数据", {
      track: track.title,
      currentTime: Number(track.audio.currentTime.toFixed(2)),
      readyState: track.audio.readyState,
      networkState: track.audio.networkState,
      visibilityState: document.visibilityState,
    });
  });
  audio.addEventListener("stalled", () => {
    console.warn(LOG_PREFIX, "音频加载停滞", {
      track: track.title,
      currentTime: Number(track.audio.currentTime.toFixed(2)),
      readyState: track.audio.readyState,
      networkState: track.audio.networkState,
      visibilityState: document.visibilityState,
    });
  });
  audio.addEventListener("error", () => {
    console.error(LOG_PREFIX, "音频错误", {
      track: track.title,
      mediaError: track.audio.error?.code || null,
      message: track.audio.error?.message || "",
      currentTime: Number(track.audio.currentTime.toFixed(2)),
      visibilityState: document.visibilityState,
    });
  });
  audio.addEventListener("ended", () => updateTrackRow(track));

  return track;
}

function renderTracks() {
  if (state.tracks.length === 0) {
    trackList.innerHTML = '<p class="empty-state">还没有歌曲，点右上角添加。</p>';
    return;
  }

  const fragment = document.createDocumentFragment();
  for (const track of state.tracks) {
    if (!state.rows.has(track.id)) {
      state.rows.set(track.id, createTrackRow(track));
    }
    fragment.append(state.rows.get(track.id).row);
  }
  trackList.replaceChildren(fragment);
  for (const track of state.tracks) {
    updateTrackRow(track);
  }
}

function createTrackRow(track) {
  const row = document.createElement("article");
  row.className = "track-row";

  const main = document.createElement("div");
  main.className = "track-main";

  const cover = document.createElement("div");
  cover.className = "track-cover";
  const art = document.createElement("div");
  art.className = "cover-art";
  art.setAttribute("aria-hidden", "true");
  cover.append(art);

  const body = document.createElement("div");
  body.className = "track-body";

  const head = document.createElement("div");
  head.className = "track-head";

  const info = document.createElement("div");
  info.className = "track-info";
  const titleRow = document.createElement("div");
  titleRow.className = "title-row";
  const eq = document.createElement("span");
  eq.className = "eq";
  eq.setAttribute("aria-hidden", "true");
  eq.append(document.createElement("i"), document.createElement("i"), document.createElement("i"));
  const title = document.createElement("div");
  title.className = "track-title";
  title.textContent = displayTitle(track.title);
  title.title = track.title;
  titleRow.append(eq, title);
  const meta = document.createElement("div");
  meta.className = "track-meta";
  info.append(titleRow, meta);
  info.addEventListener("click", () => {
    setActiveTrack(track);
  });

  const actions = document.createElement("div");
  actions.className = "track-actions";
  const playButton = createIconButton("play", "icon-btn play-btn", "播放");
  playButton.addEventListener("click", () => togglePlayback(track));
  const deleteButton = createIconButton("trash", "icon-btn delete-button", "从列表移除");
  deleteButton.addEventListener("click", () => removeTrack(track));
  actions.append(playButton, deleteButton);
  const volume = createVolume(track);
  head.append(info, volume.wrap, actions);
  body.append(head);
  main.append(cover, body);
  row.append(main);

  return {
    row,
    playButton,
    meta,
    volume,
  };
}

function createVolume(track) {
  const wrap = document.createElement("div");
  wrap.className = "volume";
  wrap.addEventListener("click", (event) => {
    event.stopPropagation();
  });
  const icon = document.createElement("span");
  icon.className = "volume-icon";
  icon.setAttribute("aria-hidden", "true");
  const slider = document.createElement("input");
  slider.className = "volume-slider";
  slider.type = "range";
  slider.min = "0";
  slider.max = "1";
  slider.step = "0.01";
  slider.value = String(track.volume);
  slider.setAttribute("aria-label", "音量");
  slider.addEventListener("input", () => {
    setTrackVolume(track, Number(slider.value));
    updateTrackRow(track);
  });
  const label = document.createElement("span");
  label.className = "volume-label";
  wrap.append(icon, slider, label);
  return { wrap, icon, slider, label };
}

function updateTrackRow(track) {
  const view = state.rows.get(track.id);
  if (!view) return;

  const isActive = state.activeId === track.id;
  const isPlaying = !track.audio.paused;
  view.row.classList.toggle("is-active", isActive);
  view.row.classList.toggle("is-playing", isPlaying);
  setButtonIcon(view.playButton, isPlaying ? "pause" : "play");
  view.playButton.setAttribute("aria-label", isPlaying ? "暂停" : "播放");
  view.playButton.title = isPlaying ? "暂停" : "播放";
  view.playButton.disabled = !track.canPlay;
  view.meta.textContent = track.error
    ? `${track.extension.toUpperCase()} · 浏览器不支持播放`
    : track.metadata;
  const percent = Math.round(track.volume * 100);
  setButtonIcon(view.volume.icon, volumeIconName(track.volume));
  if (Number(view.volume.slider.value) !== track.volume) {
    view.volume.slider.value = String(track.volume);
  }
  view.volume.slider.style.setProperty("--p", String(track.volume));
  view.volume.slider.disabled = !track.canPlay;
  view.volume.label.textContent = `${percent}%`;
  view.volume.wrap.classList.toggle("is-disabled", !track.canPlay);
}

function setActiveTrack(track) {
  if (state.activeId === track.id) return;
  const previous = state.tracks.find((item) => item.id === state.activeId);
  state.activeId = track.id;
  if (previous) updateTrackRow(previous);
  updateTrackRow(track);
}

async function togglePlayback(track) {
  clearError();
  if (!track.audio.paused) {
    track.audio.pause();
    logPlaybackState(track, "pause");
    return;
  }

  try {
    await ensureAudioOutput(track);
    await track.audio.play();
    logPlaybackState(track, "play");
  } catch (error) {
    showError(`无法播放「${track.title}」：${error.message || "浏览器拒绝播放"}`);
  }
}

function ensureAudioContext() {
  if (state.audioContext) return state.audioContext;
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  if (!AudioContextClass) return null;
  state.audioContext = new AudioContextClass();
  state.audioContext.addEventListener("statechange", () => {
    console.info(LOG_PREFIX, "Web Audio 状态变化", {
      state: state.audioContext?.state,
      visibilityState: document.visibilityState,
      activeTracks: state.tracks.filter((track) => !track.audio.paused).map((track) => track.title),
    });
  });
  return state.audioContext;
}

async function ensureAudioOutput(track) {
  if (track.sourceNode) {
    if (state.audioContext?.state === "suspended") {
      await state.audioContext.resume();
    }
    return;
  }

  const context = ensureAudioContext();
  if (!context) {
    console.warn(LOG_PREFIX, "Web Audio 不可用，回退到原生 Audio 多轨");
    return;
  }
  if (context.state === "suspended") {
    await context.resume();
  }

  track.sourceNode = context.createMediaElementSource(track.audio);
  track.gainNode = context.createGain();
  track.audio.volume = 1;
  track.gainNode.gain.setValueAtTime(track.volume, context.currentTime);
  track.sourceNode.connect(track.gainNode);
  track.gainNode.connect(context.destination);
}

function setTrackVolume(track, volume) {
  track.volume = Math.min(1, Math.max(0, volume));
  if (!track.gainNode) {
    track.audio.volume = track.volume;
    return;
  }
  track.audio.volume = 1;
  const now = state.audioContext.currentTime;
  track.gainNode.gain.cancelScheduledValues(now);
  track.gainNode.gain.setValueAtTime(track.volume, now);
}

function logPlaybackState(track, action) {
  const playingTitles = state.tracks.filter((item) => !item.audio.paused).map((item) => item.title);
  console.info(LOG_PREFIX, "播放状态", {
    action,
    track: track.title,
    playingCount: playingTitles.length,
    playingTitles,
  });
}

function removeTrack(track) {
  disconnectTrackAudio(track);
  track.audio.pause();
  track.audio.src = "";
  URL.revokeObjectURL(track.url);
  state.objectUrls.delete(track.url);
  state.tracks = state.tracks.filter((item) => item.id !== track.id);
  state.rows.delete(track.id);
  if (state.activeId === track.id) {
    state.activeId = state.tracks.find((item) => item.canPlay)?.id || state.tracks[0]?.id || null;
  }
  renderTracks();
  saveLibrary(state.tracks.map((item) => item.file)).catch((error) => {
    console.error(LOG_PREFIX, "更新本地音乐失败", error);
  });
}

function disconnectTrackAudio(track) {
  track.sourceNode?.disconnect();
  track.gainNode?.disconnect();
  track.sourceNode = null;
  track.gainNode = null;
}

function releaseTracks() {
  for (const track of state.tracks) {
    disconnectTrackAudio(track);
    track.audio.pause();
    track.audio.src = "";
  }
  for (const url of state.objectUrls) {
    URL.revokeObjectURL(url);
  }
  state.objectUrls.clear();
  state.rows.clear();
}

function displayTitle(name) {
  const dot = name.lastIndexOf(".");
  if (dot <= 0) return name;
  return name.slice(0, dot);
}

function describeFile(file, extension) {
  return `${extension.toUpperCase()} · ${formatBytes(file.size)}`;
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
}

function getExtension(name) {
  return name.split(".").pop().toLowerCase();
}

function trackKey(file) {
  return `${file.name}:${file.size}:${file.lastModified}`;
}

function createId() {
  if (globalThis.crypto?.randomUUID) {
    return globalThis.crypto.randomUUID();
  }
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

const ICONS = {
  play: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 5.14v13.72L19 12 8 5.14z"/></svg>',
  pause: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 5h4v14H6V5zm8 0h4v14h-4V5z"/></svg>',
  vol: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M11 5.07 6 9H3v6h3l5 3.93V5.07zM15.54 8.46a5 5 0 010 7.07 1 1 0 11-1.42-1.42 3 3 0 000-4.24 1 1 0 111.42-1.41zm2.12-2.12a8 8 0 010 11.31 1 1 0 11-1.42-1.42 6 6 0 000-8.49 1 1 0 111.42-1.4z"/></svg>',
  volLow: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M11 5.07 6 9H3v6h3l5 3.93V5.07zM15.54 8.46a5 5 0 010 7.07 1 1 0 11-1.42-1.42 3 3 0 000-4.24 1 1 0 111.42-1.41z"/></svg>',
  mute: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M11 5.07 6 9H3v6h3l5 3.93V5.07zM16 9.17l1.41-1.42L21 11.34l-3.59 3.59L16 13.51l1.41-1.41-1.41-1.41 1.41-1.41zm2.83 2.83 1.41 1.41L19.83 16l1.41 1.41-1.41 1.41-1.41-1.41-1.41 1.41-1.41-1.41 1.41-1.41-1.41-1.41 1.41-1.41z"/></svg>',
  trash: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 3h6l1 2h4v2H4V5h4l1-2zm1 6h2v9h-2V9zm4 0h2v9h-2V9zM7 9h2v9H7V9z"/></svg>',
  plus: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M11 5h2v14h-2zM5 11h14v2H5z"/></svg>',
  gear: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M19.14 12.94c.04-.31.06-.63.06-.94s-.02-.63-.06-.94l2.03-1.58a.5.5 0 0 0 .12-.64l-1.92-3.32a.5.5 0 0 0-.6-.22l-2.39.96a7.2 7.2 0 0 0-1.63-.94l-.36-2.54a.5.5 0 0 0-.49-.42h-3.8a.5.5 0 0 0-.49.42l-.36 2.54c-.58.23-1.12.54-1.63.94l-2.39-.96a.5.5 0 0 0-.6.22L2.71 8.48a.5.5 0 0 0 .12.64l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58a.5.5 0 0 0-.12.64l1.92 3.32c.13.22.39.31.6.22l2.39-.96c.51.4 1.05.71 1.63.94l.36 2.54c.05.24.25.42.49.42h3.8c.24 0 .44-.18.49-.42l.36-2.54c.58-.23 1.12-.54 1.63-.94l2.39.96c.22.09.47 0 .6-.22l1.92-3.32a.5.5 0 0 0-.12-.64l-2.03-1.58zM12 15.5A3.5 3.5 0 1 1 12 8.5a3.5 3.5 0 0 1 0 7z"/></svg>',
};

function volumeIconName(volume) {
  if (volume === 0) return "mute";
  if (volume < 0.35) return "volLow";
  return "vol";
}

function setButtonIcon(button, name) {
  button.innerHTML = ICONS[name] || "";
}

function createIconButton(iconName, className, label) {
  const button = createButton("", className, label);
  setButtonIcon(button, iconName);
  return button;
}

function createButton(text, className, label) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = className;
  if (text) button.textContent = text;
  button.setAttribute("aria-label", label);
  button.title = label;
  return button;
}

function mountHeaderIcons() {
  const addButton = document.querySelector('.library-header [data-action="choose-music"]');
  const settingsButton = document.querySelector('[data-action="settings"]');
  if (addButton) {
    addButton.textContent = "";
    setButtonIcon(addButton, "plus");
  }
  if (settingsButton) setButtonIcon(settingsButton, "gear");
}

function openSettings() {
  stopToggle.checked = state.stop.on;
  stopTimeInput.value = state.stop.time;
  settingsDialog.showModal();
}

function loadStop() {
  const raw = localStorage.getItem(STOP_KEY);
  if (!raw) return { on: false, time: "23:00" };
  let data;
  try {
    data = JSON.parse(raw);
  } catch (error) {
    throw new Error("自动停止设置已损坏", { cause: error });
  }
  return {
    on: data?.on === true,
    time: parseStopTime(data?.time),
  };
}

function persistStop() {
  try {
    localStorage.setItem(STOP_KEY, JSON.stringify({ on: state.stop.on, time: state.stop.time }));
  } catch (error) {
    throw new Error("无法保存自动停止设置", { cause: error });
  }
  console.info(LOG_PREFIX, "自动停止设置", state.stop);
}

function parseStopTime(value) {
  const match = /^(\d{2}):(\d{2})(?::\d{2})?$/.exec(value || "");
  const hour = Number(match?.[1]);
  const minute = Number(match?.[2]);
  if (!match || hour > 23 || minute > 59) {
    throw new Error("停止时间无效");
  }
  return `${match[1]}:${match[2]}`;
}

function nextStopAt(time, from) {
  const [hour, minute] = time.split(":").map(Number);
  const target = new Date(from);
  target.setHours(hour, minute, 0, 0);
  if (target.getTime() <= from) target.setDate(target.getDate() + 1);
  return target.getTime();
}

function syncStop() {
  window.clearTimeout(state.stopTimer);
  state.stopTimer = 0;
  renderStopNote();
  if (!state.stop.on) {
    state.stopDue = 0;
    return;
  }

  const now = Date.now();
  if (state.stopDue && now >= state.stopDue - 250) {
    const firedAt = state.stopDue;
    state.stopDue = 0;
    stopAllPlaying();
    state.stopDue = nextStopAt(state.stop.time, firedAt);
  } else {
    state.stopDue = nextStopAt(state.stop.time, now);
  }

  state.stopTimer = window.setTimeout(syncStop, Math.max(0, state.stopDue - Date.now()));
  console.info(LOG_PREFIX, "已安排自动停止", {
    time: state.stop.time,
    due: new Date(state.stopDue).toISOString(),
  });
}

function stopAllPlaying() {
  const playing = state.tracks.filter((track) => !track.audio.paused);
  for (const track of playing) track.audio.pause();
  console.info(LOG_PREFIX, "自动停止触发", {
    time: state.stop.time,
    count: playing.length,
    titles: playing.map((track) => track.title),
  });
  if (!playing.length) return;
  setStatus(`已到 ${state.stop.time}，播放已暂停`);
  window.setTimeout(() => {
    if (statusMessage.textContent.startsWith("已到 ")) clearStatus();
  }, 4000);
}

function renderStopNote() {
  stopNote.textContent = state.stop.on ? `${state.stop.time} 自动停止` : "";
  stopNote.classList.toggle("is-hidden", !state.stop.on);
}

function showError(message) {
  errorMessage.textContent = message;
  errorMessage.classList.remove("is-hidden");
}

function clearError() {
  errorMessage.textContent = "";
  errorMessage.classList.add("is-hidden");
}

function setStatus(message) {
  statusMessage.textContent = message;
  statusMessage.classList.remove("is-hidden");
}

function clearStatus() {
  statusMessage.textContent = "";
  statusMessage.classList.add("is-hidden");
}

function reportLoadError(error) {
  console.error(LOG_PREFIX, "文件加载失败", error);
  clearStatus();
  showError(`读取音乐失败：${error.message || "浏览器无法读取所选文件"}`);
}

mountHeaderIcons();
try {
  state.stop = loadStop();
} catch (error) {
  console.error(LOG_PREFIX, "读取自动停止设置失败", error);
  state.stop = { on: false, time: "23:00" };
}
stopToggle.checked = state.stop.on;
stopTimeInput.value = state.stop.time;
renderTracks();
syncStop();

restoreLibrary().catch((error) => {
  console.error(LOG_PREFIX, "恢复本地音乐失败", error);
});
