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
            Color.windowBackground
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
                    onImport: importFolder
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
                Image(systemName: "folder.fill")
                    .font(.system(size: 72, weight: .medium))
                    .foregroundStyle(Color.primaryBlue)

                Spacer().frame(height: 28)

                Text("AudioDirectory")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.ink)

                Spacer().frame(height: 12)

                Text("Choose a folder containing audio\nfiles to begin.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.subtleInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Spacer().frame(height: 32)

                Button(action: onContinue) {
                    HStack(spacing: 10) {
                        Text(". /START")
                            .font(.system(size: 16, weight: .bold))

                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.primaryBlue, Color.primaryBlueBright],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: Color.ink.opacity(0.12), radius: 18, y: 10)
                }
                .buttonStyle(.plain)
                .focusable()
            }
            .frame(width: 236)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 48)
    }
}

private struct LibraryScreen: View {
    let tracks: [AudioAsset]
    @Binding var activeTrackID: UUID?
    let currentFolder: URL
    @ObservedObject var playback: AudioPlaybackController
    let onImport: () -> Void

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
                            onSelect: {
                                activeTrackID = track.id
                            },
                            onTogglePlayback: {
                                activeTrackID = track.id
                                playback.togglePlayback(for: track)
                            }
                        )
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.never)

            footer
        }
        .background(Color.surfaceLowest)
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.subtleInk.opacity(0.7))

                ForEach(Array(breadcrumbParts.enumerated()), id: \.offset) { index, part in
                    if index > 0 {
                        Text("/")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.subtleInk.opacity(0.45))
                    }

                    Text(part)
                        .font(.system(size: 12, weight: index == breadcrumbParts.count - 1 ? .semibold : .medium))
                        .foregroundStyle(index == breadcrumbParts.count - 1 ? Color.ink : Color.subtleInk.opacity(0.82))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onImport) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("Import")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.primaryBlue, Color.primaryBlueBright],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.04))
                .frame(height: 0.5)
        }
    }

    private var footer: some View {
        HStack {
            Text(footerSummary)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.subtleInk.opacity(0.78))

            Spacer()

            Image(systemName: footerHasPlayback ? "waveform" : "pause.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(footerHasPlayback ? Color.primaryBlue : Color.subtleInk.opacity(0.55))
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(Color.surfaceLowest)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.04))
                .frame(height: 0.5)
        }
    }

    private var footerHasPlayback: Bool {
        playback.playingTrackCount > 0
    }

    private var footerSummary: String {
        let baseSummary =
            "\(tracks.count) item\(tracks.count == 1 ? "" : "s") in \(currentFolder.lastPathComponent)"

        let playingCount = playback.playingTrackCount
        if playingCount > 0 {
            return "\(baseSummary) • \(playingCount) playing"
        }

        return baseSummary
    }

    private var breadcrumbParts: [String] {
        let parts = currentFolder.pathComponents.suffix(3).filter { $0 != "/" }
        return ["~"] + parts
    }
}

private struct TrackRow: View {
    let track: AudioAsset
    let isActive: Bool
    let isPlaying: Bool
    let progress: Double
    let onSelect: () -> Void
    let onTogglePlayback: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onSelect) {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: track.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(iconColor)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.ink)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(track.metadata)
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(metadataColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Spacer(minLength: 0)

                        Button(action: onTogglePlayback) {
                            Image(systemName: playbackIcon)
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(playbackColor)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                        .disabled(!track.canPlay)
                    }

                    Group {
                        if isActive || isPlaying {
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.primaryBlue.opacity(0.12))

                                    Capsule()
                                        .fill(Color.primaryBlue)
                                        .frame(width: max(proxy.size.width * progress, 0))
                                }
                            }
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    Rectangle()
                        .fill(isActive ? Color.primaryBlue.opacity(0.08) : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.black.opacity(0.03))
                .frame(height: 0.5)
                .padding(.leading, 16)
        }
    }

    private var iconColor: Color {
        isActive ? .primaryBlue : Color.subtleInk.opacity(track.canPlay ? 0.55 : 0.42)
    }

    private var metadataColor: Color {
        Color.subtleInk.opacity(isActive ? 0.65 : 0.42)
    }

    private var playbackIcon: String {
        if !track.canPlay {
            return "play.circle.fill"
        }
        return isPlaying ? "pause.circle.fill" : "play.circle.fill"
    }

    private var playbackColor: Color {
        if !track.canPlay {
            return Color.subtleInk.opacity(0.28)
        }
        return isActive || isPlaying ? .primaryBlue : Color.subtleInk.opacity(0.42)
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
    let icon: String
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
                    icon: "music.note",
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
                icon: "folder.fill",
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
    static let primaryBlue = Color(hex: 0x0058BC)
    static let primaryBlueBright = Color(hex: 0x0070EB)
    static let ink = Color(hex: 0x1A1C1D)
    static let subtleInk = Color(hex: 0x6C7281)
    static let surfaceLowest = Color(hex: 0xFFFFFF)
    static let windowBackground = Color(hex: 0xF9F9FB)

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
