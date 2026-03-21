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
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        panel.message = "Choose a folder containing audio files."

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

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
                            onSelect: {
                                activeTrackID = track.id
                            },
                            onTogglePlayback: {
                                activeTrackID = track.id
                                playback.togglePlayback(for: track)
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
    let onSelect: () -> Void
    let onTogglePlayback: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onTogglePlayback) {
                    Image(systemName: playbackIcon)
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(playbackColor)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 22, height: 22, alignment: .center)
                }
                .buttonStyle(.plain)
                .disabled(!track.canPlay)

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
                .buttonStyle(.plain)

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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Rectangle().fill(rowBackground))
            .contentShape(Rectangle())

            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 0.5)
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
}

@MainActor
private final class AudioPlaybackController: ObservableObject {
    @Published private(set) var playingTrackIDs: Set<UUID> = []
    @Published private(set) var progressValues: [UUID: Double] = [:]

    private var players: [UUID: AVPlayer] = [:]
    private var timeObservers: [UUID: Any] = [:]
    private var endObservers: [UUID: NSObjectProtocol] = [:]

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
        progressValues.removeValue(forKey: track.id)
    }

    private func startPlayback(for track: AudioAsset, url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        players[track.id] = player
        progressValues[track.id] = 0
        attachObservers(for: player, item: item, trackID: track.id)
        player.play()
        playingTrackIDs.insert(track.id)
    }

    private func resume(player: AVPlayer, trackID: UUID) {
        player.play()
        playingTrackIDs.insert(trackID)
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
                self.progressValues[trackID] = 1
                self.playingTrackIDs.remove(trackID)
                self.players[trackID]?.seek(to: .zero)
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
