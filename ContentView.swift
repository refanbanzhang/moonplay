import AppKit
import AVFoundation
import SwiftUI

struct ContentView: View {
    @State private var stage: ScreenStage = .welcome
    @State private var activeTrackID: UUID?
    @State private var tracks: [AudioAsset] = []
    @StateObject private var playback = AudioPlaybackController()

    var body: some View {
        ZStack {
            Color.surfaceLowest
                .ignoresSafeArea()

            switch stage {
            case .welcome:
                WelcomeScreen(onContinue: importFolder)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .library(let folder):
                LibraryScreen(
                    tracks: tracks,
                    activeTrackID: $activeTrackID,
                    currentFolder: folder,
                    playback: playback,
                    onImport: importFolder,
                    onDeleteTrack: removeTrack
                )
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
        .frame(width: AppWindow.width, height: AppWindow.height)
        .onChange(of: stage) { _, newStage in
            if case .welcome = newStage {
                playback.stop()
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: stage)
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: tracks.count)
    }

    private func importFolder() {
        let selectedURL = AppPaths.defaultAudioFolder
        let importedTracks = AudioAsset.load(from: selectedURL)
        let nextTracks = importedTracks.isEmpty ? AudioAsset.placeholder(for: selectedURL) : importedTracks
        playback.stop()

        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            tracks = nextTracks
            activeTrackID = nextTracks.first(where: \.canPlay)?.id ?? nextTracks.first?.id
            stage = .library(folder: selectedURL)
        }
    }

    private func removeTrack(_ track: AudioAsset) {
        playback.stopPlayback(for: track)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            tracks.removeAll { $0.id == track.id }
            if activeTrackID == track.id {
                activeTrackID = tracks.first?.id
            }
        }
    }
}

private enum ScreenStage: Equatable {
    case welcome
    case library(folder: URL)
}

private enum AppPaths {
    static let defaultAudioFolder = URL(fileURLWithPath: "/Users/rfbz/Desktop/music", isDirectory: true)
}

private struct WelcomeScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 0) {
                Image(systemName: "folder")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(Color.welcomeIcon)

                Spacer().frame(height: 32)

                Text("AudioDirectory")
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(Color.ink)

                Spacer().frame(height: 12)

                Text("Choose a folder containing audio files to begin.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.subtleInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 8)

                Spacer().frame(height: 40)

                Button(action: onContinue) {
                    Text("./START")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.startBtnText)
                        .frame(maxWidth: 280)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.startBtnBg)
                        )
                }
                .buttonStyle(.welcomeStart)
                .focusable()
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
    }
}

private struct WelcomeStartButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private extension ButtonStyle where Self == WelcomeStartButtonStyle {
    static var welcomeStart: WelcomeStartButtonStyle { WelcomeStartButtonStyle() }
}

private struct LibraryScreen: View {
    let tracks: [AudioAsset]
    @Binding var activeTrackID: UUID?
    let currentFolder: URL
    @ObservedObject var playback: AudioPlaybackController
    let onImport: () -> Void
    let onDeleteTrack: (AudioAsset) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(tracks) { track in
                        TrackRow(
                            track: track,
                            isActive: activeTrackID == track.id,
                            isPlaying: playback.isPlaying(track),
                            progress: playback.progress(for: track),
                            currentTime: playback.currentTime(for: track),
                            duration: playback.duration(for: track),
                            volume: playback.volume(for: track),
                            showsProgress: playback.hasPlaybackState(for: track),
                            canSeek: playback.canSeek(track),
                            onSelect: {
                                activeTrackID = track.id
                            },
                            onTogglePlayback: {
                                activeTrackID = track.id
                                playback.togglePlayback(for: track)
                            },
                            onSeek: { progress in
                                playback.seek(to: progress, for: track)
                            },
                            onVolumeChange: { volume in
                                playback.setVolume(volume, for: track)
                            },
                            onDelete: {
                                onDeleteTrack(track)
                            }
                        )
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.never)
        }
        .background(Color.surfaceLowest)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 4) {
                Text("./")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.subtleInk.opacity(0.4))

                Text("Audio")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primaryBlue)

                Text("./")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Color.subtleInk.opacity(0.3))

                Text(currentFolder.lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.subtleInk.opacity(0.4))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onImport) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.subtleInk)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.libraryAdd)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color.surfaceLowest)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.04))
                .frame(height: 0.5)
        }
    }
}

private struct LibraryAddButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(Color.black.opacity(configuration.isPressed ? 0.08 : 0.04))
            )
    }
}

private extension ButtonStyle where Self == LibraryAddButtonStyle {
    static var libraryAdd: LibraryAddButtonStyle { LibraryAddButtonStyle() }
}

private struct TrackRow: View {
    let track: AudioAsset
    let isActive: Bool
    let isPlaying: Bool
    let progress: Double
    let currentTime: Double
    let duration: Double
    let volume: Double
    let showsProgress: Bool
    let canSeek: Bool
    let onSelect: () -> Void
    let onTogglePlayback: () -> Void
    let onSeek: (Double) -> Void
    let onVolumeChange: (Double) -> Void
    let onDelete: () -> Void

    @State private var scrubProgress: Double = 0
    @State private var isScrubbing = false
    @State private var showsVolumeSlider = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onTogglePlayback) {
                    Image(systemName: playbackIcon)
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(playbackColor)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 22, height: 22, alignment: .center)
                }
                .buttonStyle(.plain)
                .disabled(!track.canPlay)

                VStack(alignment: .leading, spacing: 8) {
                    Button(action: onSelect) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.ink)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(track.metadata)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(metadataColor)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .buttonStyle(.plain)

                    if showsProgress {
                        VStack(alignment: .leading, spacing: 4) {
                            Slider(
                                value: scrubberValue,
                                in: 0...1,
                                onEditingChanged: handleScrubbingChange
                            )
                            .controlSize(.small)
                            .tint(track.canPlay ? .primaryBlue : Color.subtleInk.opacity(0.2))
                            .disabled(!canSeek)

                            HStack(spacing: 8) {
                                Text(formattedElapsedTime)

                                Spacer(minLength: 0)

                                Text(formattedDuration)
                            }
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.subtleInk.opacity(0.72))
                        }
                    }

                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 6) {
                        Button(action: {
                            guard track.canPlay else { return }
                            withAnimation(.easeOut(duration: 0.18)) {
                                showsVolumeSlider.toggle()
                            }
                        }) {
                            Image(systemName: volumeIcon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.subtleInk.opacity(track.canPlay ? 0.72 : 0.36))
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!track.canPlay)
                        .popover(isPresented: $showsVolumeSlider, arrowEdge: .top) {
                            VStack(spacing: 6) {
                                VerticalSlider(value: volumeBinding)
                                    .frame(width: 22, height: 120)

                                Text(volumeLabel)
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color.subtleInk.opacity(0.72))
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .frame(width: 52)
                        }
                    }

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.subtleInk.opacity(0.45))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("从列表移除")
                    .accessibilityLabel("删除")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Rectangle().fill(rowBackground))
            .contentShape(Rectangle())

            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 0.5)
        }
        .onAppear {
            scrubProgress = progress
        }
        .onChange(of: progress) { _, newValue in
            guard !isScrubbing else { return }
            scrubProgress = newValue
        }
    }

    private var rowBackground: Color {
        if isActive {
            return Color.primaryBlue.opacity(0.04)
        }
        return Color.clear
    }

    private var metadataColor: Color {
        Color.subtleInk.opacity(isActive ? 0.6 : 0.5)
    }

    private var playbackIcon: String {
        if !track.canPlay {
            return "play.circle"
        }
        return isPlaying ? "pause.circle.fill" : "play.circle"
    }

    private var playbackColor: Color {
        if !track.canPlay {
            return Color.subtleInk.opacity(0.28)
        }
        return isActive || isPlaying ? .primaryBlue : Color.subtleInk.opacity(0.4)
    }

    private var scrubberValue: Binding<Double> {
        Binding(
            get: {
                isScrubbing ? scrubProgress : progress
            },
            set: { newValue in
                let clampedValue = min(max(newValue, 0), 1)
                scrubProgress = clampedValue
                guard isScrubbing else { return }
                onSeek(clampedValue)
            }
        )
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { volume },
            set: { newValue in
                onVolumeChange(min(max(newValue, 0), 1))
            }
        )
    }

    private var volumeIcon: String {
        switch volume {
        case 0:
            return "speaker.slash.fill"
        case ..<0.4:
            return "speaker.wave.1.fill"
        default:
            return "speaker.wave.2.fill"
        }
    }

    private var volumeLabel: String {
        "\(Int((volume * 100).rounded()))%"
    }

    private var displayedElapsedTime: Double {
        if isScrubbing {
            return duration * scrubProgress
        }
        return currentTime
    }

    private var formattedElapsedTime: String {
        guard canSeek else { return "00:00" }
        return Self.formatTime(displayedElapsedTime)
    }

    private var formattedDuration: String {
        guard canSeek else { return "--:--" }
        return Self.formatTime(duration)
    }

    private func handleScrubbingChange(_ editing: Bool) {
        if editing {
            scrubProgress = progress
            isScrubbing = true
            return
        }

        onSeek(scrubProgress)
        isScrubbing = false
    }

    private static func formatTime(_ seconds: Double) -> String {
        let totalSeconds = max(Int(seconds.rounded()), 0)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private struct VerticalSlider: View {
    @Binding var value: Double

    var body: some View {
        GeometryReader { geometry in
            let trackWidth: CGFloat = 4
            let knobSize: CGFloat = 12
            let availableHeight = max(geometry.size.height - knobSize, 1)
            let clampedValue = min(max(value, 0), 1)
            let knobOffset = availableHeight * CGFloat(1 - clampedValue)

            ZStack(alignment: .top) {
                Capsule()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: trackWidth)

                Capsule()
                    .fill(Color.primaryBlue)
                    .frame(width: trackWidth, height: max((1 - knobOffset / availableHeight) * availableHeight + knobSize / 2, knobSize / 2))
                    .frame(maxHeight: .infinity, alignment: .bottom)

                Circle()
                    .fill(Color.primaryBlue)
                    .frame(width: knobSize, height: knobSize)
                    .offset(y: knobOffset)
                    .shadow(color: Color.black.opacity(0.14), radius: 1, y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let location = min(max(gesture.location.y - knobSize / 2, 0), availableHeight)
                        value = Double(1 - location / availableHeight)
                    }
            )
        }
    }
}

@MainActor
private final class AudioPlaybackController: ObservableObject {
    @Published private(set) var playingTrackIDs: Set<UUID> = []
    @Published private(set) var progressValues: [UUID: Double] = [:]
    @Published private(set) var currentTimes: [UUID: Double] = [:]
    @Published private(set) var durations: [UUID: Double] = [:]
    @Published private(set) var volumeValues: [UUID: Double] = [:]

    private var players: [UUID: AVPlayer] = [:]
    private var timeObservers: [UUID: Any] = [:]
    private var endObservers: [UUID: NSObjectProtocol] = [:]
    private var pendingSeekTimes: [UUID: Double] = [:]

    var playingTrackCount: Int {
        playingTrackIDs.count
    }

    func togglePlayback(for track: AudioAsset) {
        guard track.canPlay, let url = track.url else {
            NSSound.beep()
            return
        }

        if let player = players[track.id] {
            if playingTrackIDs.contains(track.id) {
                pause(trackID: track.id)
            } else {
                resume(player: player, trackID: track.id)
            }
            return
        }

        startPlayback(for: track, url: url)
    }

    func progress(for track: AudioAsset) -> Double {
        progressValues[track.id] ?? 0
    }

    func currentTime(for track: AudioAsset) -> Double {
        currentTimes[track.id] ?? 0
    }

    func duration(for track: AudioAsset) -> Double {
        durations[track.id] ?? 0
    }

    func volume(for track: AudioAsset) -> Double {
        volumeValues[track.id] ?? 1
    }

    func hasPlaybackState(for track: AudioAsset) -> Bool {
        players[track.id] != nil
    }

    func canSeek(_ track: AudioAsset) -> Bool {
        guard players[track.id] != nil else { return false }
        guard let duration = durations[track.id] else { return false }
        return duration.isFinite && duration > 0
    }

    func seek(to progress: Double, for track: AudioAsset) {
        guard
            let player = players[track.id],
            let duration = durations[track.id],
            duration.isFinite,
            duration > 0
        else {
            return
        }

        let clampedProgress = min(max(progress, 0), 1)
        let targetSeconds = duration * clampedProgress
        currentTimes[track.id] = targetSeconds
        progressValues[track.id] = clampedProgress
        pendingSeekTimes[track.id] = targetSeconds
        seekPlayer(player, trackID: track.id, to: targetSeconds)
    }

    func setVolume(_ volume: Double, for track: AudioAsset) {
        let clampedVolume = Float(min(max(volume, 0), 1))
        volumeValues[track.id] = Double(clampedVolume)
        players[track.id]?.volume = clampedVolume
    }

    func isPlaying(_ track: AudioAsset) -> Bool {
        playingTrackIDs.contains(track.id)
    }

    func stop() {
        for trackID in Array(players.keys) {
            stop(trackID: trackID)
        }
    }

    func stopPlayback(for track: AudioAsset) {
        stop(trackID: track.id)
    }

    private func startPlayback(for track: AudioAsset, url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.volume = Float(volume(for: track))
        players[track.id] = player
        attachObservers(for: player, item: item, trackID: track.id)
        playingTrackIDs.insert(track.id)

        let startTime = pendingSeekTimes[track.id] ?? currentTimes[track.id] ?? 0
        if startTime > 0 {
            pendingSeekTimes[track.id] = startTime
            seekPlayer(player, trackID: track.id, to: startTime) { [weak self] in
                guard let self else { return }
                guard self.playingTrackIDs.contains(track.id) else { return }
                player.play()
            }
            return
        }

        progressValues[track.id] = 0
        currentTimes[track.id] = 0
        player.play()
    }

    private func resume(player: AVPlayer, trackID: UUID) {
        let resumeTime = pendingSeekTimes[trackID] ?? currentTimes[trackID] ?? 0
        guard resumeTime > 0 else {
            player.play()
            playingTrackIDs.insert(trackID)
            return
        }

        playingTrackIDs.insert(trackID)
        pendingSeekTimes[trackID] = resumeTime
        seekPlayer(player, trackID: trackID, to: resumeTime) { [weak self] in
            guard let self else { return }
            guard self.playingTrackIDs.contains(trackID) else { return }
            player.play()
        }
    }

    private func pause(trackID: UUID) {
        players[trackID]?.pause()
        playingTrackIDs.remove(trackID)
    }

    private func attachObservers(for player: AVPlayer, item: AVPlayerItem, trackID: UUID) {
        timeObservers[trackID] = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak self] currentTime in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let duration = item.duration.seconds
                guard duration.isFinite, duration > 0 else { return }
                if let pendingSeekTime = self.pendingSeekTimes[trackID] {
                    let delta = abs(currentTime.seconds - pendingSeekTime)
                    if delta > 0.12 {
                        return
                    }
                    self.pendingSeekTimes.removeValue(forKey: trackID)
                }
                self.durations[trackID] = duration
                self.currentTimes[trackID] = currentTime.seconds
                self.progressValues[trackID] = min(max(currentTime.seconds / duration, 0), 1)
            }
        }

        endObservers[trackID] = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let player = self.players[trackID] else { return }
                self.pendingSeekTimes.removeValue(forKey: trackID)
                self.currentTimes[trackID] = 0
                self.progressValues[trackID] = 0
                self.playingTrackIDs.insert(trackID)
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                    guard finished else { return }
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        guard self.playingTrackIDs.contains(trackID) else { return }
                        player.play()
                    }
                }
            }
        }
    }

    private func stop(trackID: UUID) {
        if let player = players[trackID] {
            if let timeObserver = timeObservers[trackID] {
                player.removeTimeObserver(timeObserver)
                timeObservers[trackID] = nil
            }
            player.pause()
            player.replaceCurrentItem(with: nil)
        }

        if let endObserver = endObservers[trackID] {
            NotificationCenter.default.removeObserver(endObserver)
            endObservers[trackID] = nil
        }

        players[trackID] = nil
        playingTrackIDs.remove(trackID)
        progressValues.removeValue(forKey: trackID)
        currentTimes.removeValue(forKey: trackID)
        durations.removeValue(forKey: trackID)
        volumeValues.removeValue(forKey: trackID)
        pendingSeekTimes.removeValue(forKey: trackID)
    }

    private func seekPlayer(
        _ player: AVPlayer,
        trackID: UUID,
        to seconds: Double,
        completion: (() -> Void)? = nil
    ) {
        player.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] finished in
            guard finished else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.pendingSeekTimes[trackID] == nil || abs((self.pendingSeekTimes[trackID] ?? seconds) - seconds) < 0.001 else {
                    return
                }
                self.pendingSeekTimes.removeValue(forKey: trackID)
                completion?()
            }
        }
    }

    deinit {
        let currentPlayers = players
        let currentTimeObservers = timeObservers
        let currentEndObservers = endObservers

        Task { @MainActor in
            for (trackID, player) in currentPlayers {
                if let observer = currentTimeObservers[trackID] {
                    player.removeTimeObserver(observer)
                }
            }
            for observer in currentEndObservers.values {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

private struct AudioAsset: Identifiable {
    let id = UUID()
    let title: String
    let metadata: String
    let canPlay: Bool
    let url: URL?

    static func load(from folderURL: URL) -> [AudioAsset] {
        let allowedExtensions = Set(["mp3", "wav", "m4a", "aac", "aiff", "flac", "caf"])
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .compactMap { url -> AudioAsset? in
                guard
                    allowedExtensions.contains(url.pathExtension.lowercased()),
                    let values = try? url.resourceValues(forKeys: Set(keys)),
                    values.isRegularFile == true
                else {
                    return nil
                }

                return AudioAsset(
                    title: url.lastPathComponent,
                    metadata: AudioMetadataFormatter.describe(url: url, fileSize: values.fileSize ?? 0),
                    canPlay: true,
                    url: url
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    static func placeholder(for folderURL: URL) -> [AudioAsset] {
        [
            AudioAsset(
                title: folderURL.lastPathComponent,
                metadata: "NO SUPPORTED AUDIO FILES FOUND",
                canPlay: false,
                url: nil
            )
        ]
    }
}

private enum AudioMetadataFormatter {
    static func describe(url: URL, fileSize: Int) -> String {
        let fileExtension = url.pathExtension.uppercased()
        let lightweightFormats = Set(["MP3", "M4A", "AAC"])
        let pcmFormats = Set(["WAV", "AIFF", "AIF", "CAF", "FLAC"])

        if lightweightFormats.contains(fileExtension) {
            return "\(fileExtension) • \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))"
        }

        if pcmFormats.contains(fileExtension), let audioFile = try? AVAudioFile(forReading: url) {
            let sampleRate = audioFile.processingFormat.sampleRate
            let bitsPerChannel = Int(audioFile.processingFormat.streamDescription.pointee.mBitsPerChannel)
            let frameCount = Double(audioFile.length)
            let duration = sampleRate > 0 ? frameCount / sampleRate : 0

            if bitsPerChannel > 0, sampleRate > 0, duration > 0 {
                return "\(bitsPerChannel)-BIT • \(String(format: "%.1f KHZ", sampleRate / 1000)) • \(durationString(for: duration))"
            }
        }

        return "\(fileExtension) • \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))"
    }

    private static func durationString(for seconds: Double) -> String {
        let totalSeconds = max(Int(seconds.rounded()), 0)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private extension Color {
    /// Stitch `audio_list`: primary / links
    static let primaryBlue = Color(hex: 0x007AFF)
    static let ink = Color(hex: 0x1C1C1E)
    static let subtleInk = Color(hex: 0x8E8E93)
    static let surfaceLowest = Color(hex: 0xFFFFFF)
    static let welcomeIcon = Color(hex: 0x666666)
    static let startBtnBg = Color(hex: 0xC5D9E8)
    static let startBtnText = Color(hex: 0x3A76A5)

    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

#Preview {
    ContentView()
}
