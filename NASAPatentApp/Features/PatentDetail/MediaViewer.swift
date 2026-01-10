import SwiftUI
import AVKit

// MARK: - Full Screen Zoomable Image Viewer

struct FullScreenImageViewer: View {
    let images: [String]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, urlString in
                    ZoomableImageView(urlString: urlString)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding()
                    }
                }
                Spacer()

                // Image counter
                if images.count > 1 {
                    Text("\(selectedIndex + 1) / \(images.count)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Zoomable Single Image

struct ZoomableImageView: View {
    let urlString: String

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    var body: some View {
        GeometryReader { geo in
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .contentShape(Rectangle())
                            .gesture(
                                SimultaneousGesture(
                                    // Pinch to zoom
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            lastScale = value
                                            scale = min(max(scale * delta, minScale), maxScale)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                if scale < minScale {
                                                    scale = minScale
                                                    offset = .zero
                                                    lastOffset = .zero
                                                }
                                            }
                                        },
                                    // Pan when zoomed
                                    DragGesture()
                                        .onChanged { value in
                                            if scale > 1 {
                                                offset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                            }
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                clampOffset(in: geo.size)
                                            }
                                        }
                                )
                            )
                            .gesture(
                                // Double tap to zoom
                                TapGesture(count: 2)
                                    .onEnded {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if scale > 1.0 {
                                                scale = 1.0
                                                offset = .zero
                                                lastOffset = .zero
                                            } else {
                                                scale = 3.0
                                            }
                                        }
                                    }
                            )
                    case .failure:
                        imagePlaceholder
                            .frame(width: geo.size.width, height: geo.size.height)
                    case .empty:
                        ProgressView()
                            .tint(.white)
                            .frame(width: geo.size.width, height: geo.size.height)
                    @unknown default:
                        imagePlaceholder
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
        }
    }

    private func clampOffset(in size: CGSize) {
        guard scale > 1 else {
            offset = .zero
            lastOffset = .zero
            return
        }

        // Allow panning based on how much the image extends beyond the view
        let maxX = (size.width * (scale - 1)) / 2
        let maxY = (size.height * (scale - 1)) / 2

        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
        lastOffset = offset
    }

    private var imagePlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 40))
            Text("Image unavailable")
                .font(.caption)
        }
        .foregroundStyle(.gray)
    }
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    let videoURL: String
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isYouTubeURL(videoURL) {
                YouTubePlayerView(urlString: videoURL, isPresented: $isPresented)
            } else {
                NativeVideoPlayerView(urlString: videoURL)
            }

            // Close button overlay
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }

    private func isYouTubeURL(_ url: String) -> Bool {
        url.contains("youtube.com") || url.contains("youtu.be")
    }
}

// MARK: - Native Video Player (mp4)

struct NativeVideoPlayerView: View {
    let urlString: String

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var hasError = false

    var body: some View {
        Group {
            if hasError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundStyle(.orange)
                    Text("Unable to load video")
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let url = URL(string: urlString) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "arrow.up.right")
                                Text("Open in Browser")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        }
                    }
                }
            } else if let player = player {
                VideoPlayer(player: player)
                    .onDisappear {
                        player.pause()
                    }
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .onAppear {
            loadVideo()
        }
    }

    private func loadVideo() {
        guard let url = URL(string: urlString) else {
            hasError = true
            return
        }

        let newPlayer = AVPlayer(url: url)

        // Check if video loads successfully
        newPlayer.currentItem?.asset.loadValuesAsynchronously(forKeys: ["playable"]) {
            DispatchQueue.main.async {
                var error: NSError?
                let status = newPlayer.currentItem?.asset.statusOfValue(forKey: "playable", error: &error)

                if status == .loaded {
                    self.player = newPlayer
                    self.isLoading = false
                    newPlayer.play()
                } else {
                    self.hasError = true
                    self.isLoading = false
                }
            }
        }

        // Fallback: show player after short delay if async check takes too long
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.player == nil && !self.hasError {
                self.player = newPlayer
                self.isLoading = false
                newPlayer.play()
            }
        }
    }
}

// MARK: - YouTube Web Player

struct YouTubePlayerView: View {
    let urlString: String
    @Binding var isPresented: Bool

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 24) {
            // YouTube thumbnail
            if let thumbnailURL = youTubeThumbnailURL(urlString) {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 70))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 8)
                            )
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.red)
                            )
                    }
                }
                .frame(maxWidth: 350)
            } else {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.red)
            }

            Text("YouTube Video")
                .font(.title2.bold())
                .foregroundStyle(.white)

            if let url = URL(string: urlString) {
                Button {
                    openURL(url)
                    // Close the viewer after opening YouTube
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isPresented = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Watch on YouTube")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.red)
                    .clipShape(Capsule())
                }
            }

            Text("Tap to open in YouTube app")
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }

    private func youTubeThumbnailURL(_ url: String) -> URL? {
        var videoID: String?
        if url.contains("youtube.com/watch?v=") {
            videoID = url.components(separatedBy: "v=").last?.components(separatedBy: "&").first
        } else if url.contains("youtu.be/") {
            videoID = url.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first
        }
        guard let id = videoID else { return nil }
        return URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg")
    }
}

// MARK: - Video Thumbnail

struct VideoThumbnailView: View {
    let videoURL: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isYouTubeURL(videoURL), let thumbnailURL = youTubeThumbnailURL(videoURL) {
                    AsyncImage(url: thumbnailURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            videoPlaceholder
                        }
                    }
                } else {
                    videoPlaceholder
                }

                // Play button overlay
                Circle()
                    .fill(.black.opacity(0.6))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .offset(x: 2)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var videoPlaceholder: some View {
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            VStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .font(.system(size: 40))
                Text("Video")
                    .font(.caption)
            }
            .foregroundStyle(.blue)
        )
    }

    private func isYouTubeURL(_ url: String) -> Bool {
        url.contains("youtube.com") || url.contains("youtu.be")
    }

    private func youTubeThumbnailURL(_ url: String) -> URL? {
        // Extract video ID from YouTube URL
        var videoID: String?

        if url.contains("youtube.com/watch?v=") {
            videoID = url.components(separatedBy: "v=").last?.components(separatedBy: "&").first
        } else if url.contains("youtu.be/") {
            videoID = url.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first
        }

        guard let id = videoID else { return nil }
        return URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg")
    }
}

