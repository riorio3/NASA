import SwiftUI
import AVKit

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

// MARK: - Video Player View

struct VideoPlayerView: View {
    let videoURL: String
    @Binding var isPresented: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if isYouTubeURL(videoURL) {
                // YouTube videos - show option to open externally
                youTubeView
            } else if let url = URL(string: videoURL) {
                // Direct video files - use native AVPlayer
                NativeVideoPlayer(url: url, isPresented: $isPresented)
                    .ignoresSafeArea()
            } else {
                errorView
            }
        }
    }

    private var youTubeView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.red)

                Text("YouTube Video")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("YouTube videos open in the YouTube app or Safari")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let url = URL(string: videoURL) {
                    Button {
                        openURL(url)
                        isPresented = false
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Watch on YouTube")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .clipShape(Capsule())
                    }
                }

                Button("Cancel") {
                    isPresented = false
                }
                .foregroundStyle(.gray)
                .padding(.top, 8)
            }
        }
    }

    private var errorView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                Text("Unable to Play Video")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("The video URL is invalid")
                    .font(.subheadline)
                    .foregroundStyle(.gray)

                Button("Close") {
                    isPresented = false
                }
                .foregroundStyle(.blue)
                .padding(.top)
            }
        }
    }

    private func isYouTubeURL(_ url: String) -> Bool {
        url.contains("youtube.com") || url.contains("youtu.be")
    }
}

// MARK: - Native Video Player (AVPlayerViewController with Error Handling)

struct NativeVideoPlayer: UIViewControllerRepresentable {
    let url: URL
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = VideoPlayerHostController(url: url, isPresented: $isPresented)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    class Coordinator: NSObject {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }
    }
}

// Custom host controller for better error handling
class VideoPlayerHostController: UIViewController {
    private let url: URL
    private var isPresented: Binding<Bool>
    private var playerViewController: AVPlayerViewController?
    private var player: AVPlayer?
    private var errorObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?

    init(url: URL, isPresented: Binding<Bool>) {
        self.url = url
        self.isPresented = isPresented
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPlayer()
    }

    private func setupPlayer() {
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        // Observe player item status for errors
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .failed:
                    self?.showError(item.error?.localizedDescription ?? "Failed to load video")
                case .readyToPlay:
                    // Video is ready, start playing
                    self?.player?.play()
                default:
                    break
                }
            }
        }

        // Observe for errors
        errorObservation = playerItem.observe(\.error, options: [.new]) { [weak self] item, _ in
            if let error = item.error {
                DispatchQueue.main.async {
                    self?.showError(error.localizedDescription)
                }
            }
        }

        player = AVPlayer(playerItem: playerItem)
        playerViewController = AVPlayerViewController()
        playerViewController?.player = player
        playerViewController?.delegate = self

        if let playerVC = playerViewController {
            addChild(playerVC)
            playerVC.view.frame = view.bounds
            playerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(playerVC.view)
            playerVC.didMove(toParent: self)
        }
    }

    private func showError(_ message: String) {
        // Remove player
        playerViewController?.view.removeFromSuperview()
        playerViewController?.removeFromParent()

        // Show error UI
        let errorView = UIView(frame: view.bounds)
        errorView.backgroundColor = .black
        errorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        icon.tintColor = .orange
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.heightAnchor.constraint(equalToConstant: 60).isActive = true
        icon.widthAnchor.constraint(equalToConstant: 60).isActive = true

        let title = UILabel()
        title.text = "Unable to Play Video"
        title.font = .boldSystemFont(ofSize: 20)
        title.textColor = .white

        let detail = UILabel()
        detail.text = message
        detail.font = .systemFont(ofSize: 14)
        detail.textColor = .gray
        detail.numberOfLines = 0
        detail.textAlignment = .center

        let urlLabel = UILabel()
        urlLabel.text = url.absoluteString
        urlLabel.font = .systemFont(ofSize: 10)
        urlLabel.textColor = .darkGray
        urlLabel.numberOfLines = 2
        urlLabel.textAlignment = .center

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 17)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(detail)
        stack.addArrangedSubview(urlLabel)
        stack.addArrangedSubview(closeButton)

        errorView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: errorView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: errorView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: errorView.trailingAnchor, constant: -32)
        ])

        view.addSubview(errorView)
    }

    @objc private func closeTapped() {
        isPresented.wrappedValue = false
    }

    deinit {
        errorObservation?.invalidate()
        statusObservation?.invalidate()
        player?.pause()
    }
}

extension VideoPlayerHostController: AVPlayerViewControllerDelegate {
    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        willEndFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator
    ) {
        isPresented.wrappedValue = false
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

                // YouTube badge
                if isYouTubeURL(videoURL) {
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
