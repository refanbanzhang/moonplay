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
  folderName: "",
  activeId: null,
  volumeId: null,
  objectUrls: new Set(),
};

const welcomeScreen = document.querySelector('[data-screen="welcome"]');
const libraryScreen = document.querySelector('[data-screen="library"]');
const folderInput = document.querySelector("[data-folder-input]");
const folderName = document.querySelector("[data-folder-name]");
const trackList = document.querySelector("[data-track-list]");
const errorMessage = document.querySelector("[data-error]");

document.addEventListener("click", (event) => {
  const actionButton = event.target.closest("[data-action]");
  if (actionButton?.dataset.action === "choose-folder") {
    chooseFolder();
    return;
  }

  if (!event.target.closest(".volume-wrap")) {
    state.volumeId = null;
    renderTracks();
  }
});

folderInput.addEventListener("change", async (event) => {
  const files = Array.from(event.target.files || []);
  await loadFiles(files, files[0]?.webkitRelativePath?.split("/")[0] || "本地音频");
  folderInput.value = "";
});

async function chooseFolder() {
  clearError();

  if ("showDirectoryPicker" in window) {
    try {
      const handle = await window.showDirectoryPicker({ mode: "read" });
      const files = await readDirectory(handle);
      await loadFiles(files, handle.name);
      return;
    } catch (error) {
      if (error.name === "AbortError") {
        return;
      }
      showError(`读取目录失败：${error.message || "浏览器拒绝访问该目录"}`);
      return;
    }
  }

  folderInput.click();
}

async function readDirectory(directoryHandle) {
  const files = [];

  async function readEntries(handle) {
    for await (const entry of handle.values()) {
      if (entry.kind === "file") {
        files.push(await entry.getFile());
      } else if (entry.kind === "directory") {
        await readEntries(entry);
      }
    }
  }

  await readEntries(directoryHandle);
  return files;
}

async function loadFiles(files, name) {
  const audioFiles = files
    .filter((file) => AUDIO_EXTENSIONS.has(getExtension(file.name)))
    .sort((first, second) => first.name.localeCompare(second.name, undefined, { sensitivity: "base" }));

  releaseTracks();
  state.folderName = name;
  state.tracks = audioFiles.map(createTrack);
  state.activeId = state.tracks.find((track) => track.canPlay)?.id || state.tracks[0]?.id || null;

  welcomeScreen.classList.add("is-hidden");
  libraryScreen.classList.remove("is-hidden");
  folderName.textContent = name || "本地音频";
  renderTracks();
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
    ready: false,
    duration: 0,
    error: false,
  };

  state.objectUrls.add(url);
  audio.preload = "metadata";
  audio.loop = true;
  audio.volume = 1;
  audio.addEventListener("loadedmetadata", () => {
    track.ready = true;
    track.duration = Number.isFinite(audio.duration) ? audio.duration : 0;
    renderTracks();
  });
  audio.addEventListener("error", () => {
    track.canPlay = false;
    track.error = true;
    track.ready = false;
    renderTracks();
  });
  audio.addEventListener("play", renderTracks);
  audio.addEventListener("pause", renderTracks);
  audio.addEventListener("ended", renderTracks);

  return track;
}

function renderTracks() {
  if (state.tracks.length === 0) {
    trackList.innerHTML = '<p class="empty-state">该目录中没有支持的音频文件。</p>';
    return;
  }

  trackList.replaceChildren(...state.tracks.map(renderTrack));
}

function renderTrack(track) {
  const row = document.createElement("article");
  const isActive = state.activeId === track.id;
  const isPlaying = !track.audio.paused;
  row.className = `track-row${isActive ? " is-active" : ""}`;

  const main = document.createElement("div");
  main.className = "track-main";

  const playButton = createButton(isPlaying ? "Ⅱ" : "▶", "play-button", isPlaying ? "暂停" : "播放");
  playButton.disabled = !track.canPlay;
  playButton.classList.toggle("is-active", isActive);
  playButton.classList.toggle("is-playing", isPlaying);
  playButton.addEventListener("click", () => togglePlayback(track));

  const info = document.createElement("div");
  info.className = "track-info";
  const title = document.createElement("div");
  title.className = "track-title";
  title.textContent = track.title;
  title.title = track.title;
  const meta = document.createElement("div");
  meta.className = "track-meta";
  meta.textContent = track.error ? `${track.extension.toUpperCase()} · 浏览器不支持播放` : track.metadata;
  info.append(title, meta);
  info.addEventListener("click", () => {
    state.activeId = track.id;
    renderTracks();
  });

  const actions = document.createElement("div");
  actions.className = "track-actions";
  const volumeWrap = document.createElement("div");
  volumeWrap.className = "volume-wrap";
  const volumeButton = createButton(volumeIcon(track.audio.volume), "volume-button", "音量");
  volumeButton.disabled = !track.canPlay;
  volumeButton.addEventListener("click", () => {
    state.volumeId = state.volumeId === track.id ? null : track.id;
    renderTracks();
  });
  volumeWrap.append(volumeButton);
  if (state.volumeId === track.id && track.canPlay) {
    volumeWrap.append(createVolumePopover(track));
  }

  const deleteButton = createButton("⌫", "delete-button", "从列表移除");
  deleteButton.addEventListener("click", () => removeTrack(track));
  actions.append(volumeWrap, deleteButton);
  main.append(playButton, info, actions);
  row.append(main);

  if (track.ready && track.canPlay) {
    row.append(createProgress(track));
  }

  return row;
}

function createProgress(track) {
  const wrapper = document.createElement("div");
  wrapper.className = "progress-wrap";
  const slider = document.createElement("input");
  slider.className = "progress-slider";
  slider.type = "range";
  slider.min = "0";
  slider.max = "1";
  slider.step = "0.001";
  slider.value = track.audio.duration ? track.audio.currentTime / track.audio.duration : "0";
  slider.disabled = !Number.isFinite(track.audio.duration) || track.audio.duration <= 0;
  slider.addEventListener("input", () => {
    track.audio.currentTime = Number(slider.value) * track.audio.duration;
  });

  const times = document.createElement("div");
  times.className = "track-times";
  const elapsed = document.createElement("span");
  elapsed.className = "track-time";
  elapsed.textContent = formatTime(track.audio.currentTime);
  const duration = document.createElement("span");
  duration.className = "track-time";
  duration.textContent = formatTime(track.audio.duration);
  times.append(elapsed, duration);
  wrapper.append(slider, times);
  return wrapper;
}

function createVolumePopover(track) {
  const popover = document.createElement("div");
  popover.className = "volume-popover";
  const slider = document.createElement("input");
  slider.className = "volume-slider";
  slider.type = "range";
  slider.min = "0";
  slider.max = "1";
  slider.step = "0.01";
  slider.value = String(track.audio.volume);
  slider.setAttribute("aria-label", "音量");
  slider.addEventListener("input", () => {
    track.audio.volume = Number(slider.value);
    const label = popover.querySelector(".volume-label");
    label.textContent = `${Math.round(track.audio.volume * 100)}%`;
    const button = popover.parentElement.querySelector(".volume-button");
    button.textContent = volumeIcon(track.audio.volume);
  });
  const label = document.createElement("span");
  label.className = "volume-label";
  label.textContent = `${Math.round(track.audio.volume * 100)}%`;
  popover.append(slider, label);
  return popover;
}

async function togglePlayback(track) {
  state.activeId = track.id;
  clearError();
  if (!track.audio.paused) {
    track.audio.pause();
    renderTracks();
    return;
  }

  try {
    await track.audio.play();
  } catch (error) {
    showError(`无法播放「${track.title}」：${error.message || "浏览器拒绝播放"}`);
  }
  renderTracks();
}

function removeTrack(track) {
  track.audio.pause();
  track.audio.src = "";
  URL.revokeObjectURL(track.url);
  state.objectUrls.delete(track.url);
  state.tracks = state.tracks.filter((item) => item.id !== track.id);
  if (state.activeId === track.id) {
    state.activeId = state.tracks.find((item) => item.canPlay)?.id || state.tracks[0]?.id || null;
  }
  if (state.volumeId === track.id) {
    state.volumeId = null;
  }
  renderTracks();
}

function releaseTracks() {
  for (const track of state.tracks) {
    track.audio.pause();
    track.audio.src = "";
  }
  for (const url of state.objectUrls) {
    URL.revokeObjectURL(url);
  }
  state.objectUrls.clear();
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

function formatTime(seconds) {
  if (!Number.isFinite(seconds) || seconds < 0) return "--:--";
  const totalSeconds = Math.round(seconds);
  return `${String(Math.floor(totalSeconds / 60)).padStart(2, "0")}:${String(totalSeconds % 60).padStart(2, "0")}`;
}

function getExtension(name) {
  return name.split(".").pop().toLowerCase();
}

function createId() {
  if (globalThis.crypto?.randomUUID) {
    return globalThis.crypto.randomUUID();
  }
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function volumeIcon(volume) {
  if (volume === 0) return "×";
  if (volume < 0.4) return "⌁";
  return "◖";
}

function createButton(text, className, label) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = className;
  button.textContent = text;
  button.setAttribute("aria-label", label);
  button.title = label;
  return button;
}

function showError(message) {
  errorMessage.textContent = message;
  errorMessage.classList.remove("is-hidden");
}

function clearError() {
  errorMessage.textContent = "";
  errorMessage.classList.add("is-hidden");
}

setInterval(() => {
  if (state.tracks.some((track) => !track.audio.paused)) {
    renderTracks();
  }
}, 250);
