import SwiftUI
import UIKit

// MARK: - Full Screen Zoomable Image Viewer

struct FullScreenImageViewer: View {
    let images: [String]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool

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

// MARK: - Video Player Helper

struct VideoPlayerHelper {
    static func openYouTube(url: String) {
        guard let videoID = extractVideoID(from: url) else { return }

        // Try YouTube app first, then Safari
        let youtubeAppURL = URL(string: "youtube://\(videoID)")!
        let webURL = URL(string: "https://www.youtube.com/watch?v=\(videoID)")!

        if UIApplication.shared.canOpenURL(youtubeAppURL) {
            UIApplication.shared.open(youtubeAppURL)
        } else {
            UIApplication.shared.open(webURL)
        }
    }

    private static func extractVideoID(from url: String) -> String? {
        if url.contains("youtube.com/watch?v=") {
            return url.components(separatedBy: "v=").last?.components(separatedBy: "&").first
        } else if url.contains("youtu.be/") {
            return url.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first
        } else if url.contains("youtube.com/embed/") {
            return url.components(separatedBy: "embed/").last?.components(separatedBy: "?").first
        }
        return nil
    }
}


// MARK: - Video Thumbnail

struct VideoThumbnailView: View {
    let videoURL: String
    var posterURL: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // YouTube thumbnail
                if let thumbnailURL = youTubeThumbnailURL(videoURL) {
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

                // YouTube badge
                VStack {
                    HStack {
                        Image(systemName: "play.rectangle.fill")
                            .foregroundStyle(.red)
                            .padding(6)
                            .background(.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
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
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                Text("YouTube")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
        )
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
