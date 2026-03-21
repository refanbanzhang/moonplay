import SwiftUI

struct ContentView: View {
    @State private var stage: ScreenStage = .welcome
    @State private var activeTrackID: UUID?

    private let tracks = AudioAsset.samples

    var body: some View {
        ZStack {
            workspaceBackground

            switch stage {
            case .welcome:
                WelcomeScreen {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        stage = .library
                        activeTrackID = tracks.first?.id
                    }
                }
            case .library:
                LibraryScreen(
                    tracks: tracks,
                    activeTrackID: $activeTrackID
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        stage = .welcome
                    }
                }
            }
        }
        .frame(minWidth: 960, idealWidth: 960, maxWidth: .infinity,
               minHeight: 640, idealHeight: 640, maxHeight: .infinity)
        .animation(.spring(response: 0.26, dampingFraction: 0.9), value: stage)
    }

    private var workspaceBackground: some View {
        ZStack {
            Color.canvas

            RadialGradient(
                colors: [
                    Color.white.opacity(0.82),
                    Color.white.opacity(0.0)
                ],
                center: .center,
                startRadius: 20,
                endRadius: 340
            )
            .blur(radius: 12)

            RoundedRectangle(cornerRadius: 220, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.42),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 660, height: 420)
                .blur(radius: 30)
        }
        .ignoresSafeArea()
    }
}

private enum ScreenStage {
    case welcome
    case library
}

private struct WelcomeScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 0) {
                Spacer().frame(height: 44)

                folderIcon

                Spacer().frame(height: 40)

                Text("AudioDirectory")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.ink)

                Spacer().frame(height: 10)

                Text("Choose a folder containing audio files\nto begin.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.subtleInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Spacer().frame(height: 34)

                Button(action: onContinue) {
                    HStack(spacing: 10) {
                        Text(". /START")
                            .font(.system(size: 15, weight: .bold))

                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.primaryBlue, Color.primaryBlueBright],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    }
                    .shadow(color: Color.ink.opacity(0.12), radius: 10, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 30)

                Spacer().frame(height: 34)

                HStack(spacing: 16) {
                    footerLabel("RECENT")

                    Circle()
                        .fill(Color.subtleInk.opacity(0.18))
                        .frame(width: 3, height: 3)

                    footerLabel("HELP")
                }

                Spacer()
            }
            .frame(width: 316, height: 364)
            .background(cardBackground(radius: 20))
            .shadow(color: Color.ink.opacity(0.08), radius: 28, y: 16)

            Spacer()
        }
    }

    private var folderIcon: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primaryBlue)
                .frame(width: 60, height: 40)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primaryBlue)
                .frame(width: 34, height: 11)
                .offset(x: 2, y: -9)
        }
    }

    private func footerLabel(_ title: String) -> some View {
        Button(title) {}
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(Color.subtleInk)
    }
}

private struct LibraryScreen: View {
    let tracks: [AudioAsset]
    @Binding var activeTrackID: UUID?
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                header

                VStack(spacing: 0) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        TrackRow(
                            track: track,
                            isActive: activeTrackID == track.id,
                            showsDivider: index < tracks.count - 1
                        ) {
                            activeTrackID = track.id
                        }
                    }
                }

                footer
            }
            .frame(width: 505)
            .background(cardBackground(radius: 16))
            .shadow(color: Color.ink.opacity(0.07), radius: 26, y: 14)

            Spacer(minLength: 0)
        }
    }

    private var topBar: some View {
        HStack {
            Text("Sonic Glass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.ink)

            Spacer()

            HStack(spacing: 22) {
                navItem("Library", active: true)
                navItem("Recents", active: false)
                navItem("Playlists", active: false)
            }

            Spacer()

            HStack(spacing: 18) {
                Image(systemName: "gearshape.fill")
                Image(systemName: "ellipsis.vertical")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.subtleInk)
        }
        .padding(.horizontal, 20)
        .frame(height: 42)
        .background(
            Rectangle()
                .fill(Color.white.opacity(0.78))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.black.opacity(0.03))
                        .frame(height: 0.5)
                }
        )
    }

    private func navItem(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 12.5, weight: active ? .semibold : .medium))
            .foregroundStyle(active ? Color.primaryBlue : Color.subtleInk)
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.subtleInk)

                breadcrumb("~")
                slash
                breadcrumb("Music")
                slash
                breadcrumb("Project")
                slash

                Text("2026")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.ink)
            }

            Spacer()

            Button {} label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("Import")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(Capsule(style: .continuous).fill(Color.primaryBlue))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    private func breadcrumb(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.subtleInk)
    }

    private var slash: some View {
        Text("/")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.subtleInk.opacity(0.45))
    }

    private var footer: some View {
        HStack {
            Text("6 Items • 1.2 GB available")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.subtleInk.opacity(0.78))

            Spacer()

            HStack(spacing: 14) {
                Image(systemName: "list.bullet")
                    .foregroundStyle(Color.subtleInk)
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(Color.subtleInk.opacity(0.5))
            }
            .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(Color.white.opacity(0.28))
    }
}

private struct TrackRow: View {
    let track: AudioAsset
    let isActive: Bool
    let showsDivider: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: track.icon)
                            .font(.system(size: 14, weight: isActive ? .semibold : .medium))
                            .foregroundStyle(isActive ? Color.primaryBlue : Color.subtleInk.opacity(0.55))
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                                .foregroundStyle(Color.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(track.metadata)
                                .font(.system(size: 9.5, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Color.subtleInk.opacity(isActive ? 0.68 : 0.45))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Spacer(minLength: 0)

                        HStack(spacing: 14) {
                            Image(systemName: isActive ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isActive ? Color.primaryBlue : Color.subtleInk.opacity(track.canPlay ? 0.45 : 0.24))

                            Image(systemName: "ellipsis")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.subtleInk.opacity(0.3))
                        }
                    }

                    if isActive {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primaryBlue.opacity(0.08))

                                Capsule()
                                    .fill(Color.primaryBlue)
                                    .frame(width: proxy.size.width * track.progress)
                            }
                        }
                        .frame(height: 3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, isActive ? 10 : 11)
                .padding(.bottom, isActive ? 9 : 11)
                .background(
                    Rectangle()
                        .fill(isActive ? Color.primaryBlue.opacity(0.08) : Color.clear)
                )
            }
            .buttonStyle(.plain)

            if showsDivider {
                Rectangle()
                    .fill(Color.black.opacity(0.035))
                    .frame(height: 0.5)
                    .padding(.leading, 16)
            }
        }
    }
}

private struct AudioAsset: Identifiable {
    let id = UUID()
    let title: String
    let metadata: String
    let icon: String
    let progress: CGFloat
    let canPlay: Bool

    static let samples: [AudioAsset] = [
        AudioAsset(title: "Deep_Atmosphere_Mix_01.wav", metadata: "24-BIT • 48.0 KHZ • 04:12", icon: "music.note", progress: 0.42, canPlay: true),
        AudioAsset(title: "Kick_Saturator_v3.mp3", metadata: "320KBPS • 44.1 KHZ • 00:02", icon: "doc.fill", progress: 0, canPlay: true),
        AudioAsset(title: "Ambient_Pad_Texture_Final.wav", metadata: "24-BIT • 96.0 KHZ • 02:45", icon: "doc.fill", progress: 0, canPlay: true),
        AudioAsset(title: "Vocals_Lead_Dry_01.wav", metadata: "24-BIT • 48.0 KHZ • 03:12", icon: "doc.fill", progress: 0, canPlay: true),
        AudioAsset(title: "Synth_Loop_128bpm.wav", metadata: "16-BIT • 44.1 KHZ • 00:15", icon: "doc.fill", progress: 0, canPlay: true),
        AudioAsset(title: "Drum_Rack_Stems_Group.zip", metadata: "ARCHIVE • 45.2 MB", icon: "doc.fill", progress: 0, canPlay: false)
    ]
}

private func cardBackground(radius: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
        .fill(Color.white.opacity(0.72))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.8)
        }
}

private extension Color {
    static let canvas = Color(hex: 0xF5F5F7)
    static let primaryBlue = Color(hex: 0x0058BC)
    static let primaryBlueBright = Color(hex: 0x0070EB)
    static let ink = Color(hex: 0x1A1C1D)
    static let subtleInk = Color(hex: 0x6C7281)

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
