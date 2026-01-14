import SwiftUI

struct PatentCardView: View {
    let patent: Patent
    @EnvironmentObject var patentStore: PatentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image Header - fixed height container
            imageHeader
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                .clipped()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Category Badge
            HStack(spacing: 4) {
                Image(systemName: patent.categoryIcon)
                    .font(.caption2)
                Text(patent.category)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(.blue)

            // Title
            Text(patent.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // Description Preview
            Text(patent.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            // Footer
            HStack {
                if let center = patent.center {
                    Text(center)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    toggleSave()
                } label: {
                    Image(systemName: patentStore.isSaved(patent) ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(patentStore.isSaved(patent) ? .blue : .secondary)
                }
                .accessibilityLabel(patentStore.isSaved(patent) ? "Remove from saved" : "Save patent")
            }
        }
        .padding(12)
        .frame(height: 260)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(patent.title), \(patent.category)")
        .accessibilityHint("Double tap to view details")
    }

    @ViewBuilder
    private var imageHeader: some View {
        GeometryReader { geo in
            if let imageURL = patent.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                    case .failure:
                        placeholderIcon
                            .frame(width: geo.size.width, height: geo.size.height)
                    case .empty:
                        ProgressView()
                            .frame(width: geo.size.width, height: geo.size.height)
                    @unknown default:
                        placeholderIcon
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            } else {
                placeholderIcon
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: patent.categoryIcon)
            .font(.system(size: 32))
            .foregroundStyle(.blue.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toggleSave() {
        if patentStore.isSaved(patent) {
            patentStore.removePatent(patent)
        } else {
            patentStore.savePatent(patent)
        }
    }
}

#Preview {
    PatentCardView(patent: Patent(
        id: "1",
        title: "Advanced Composite Materials",
        description: "A novel composite material system designed for extreme temperatures.",
        category: "Materials",
        caseNumber: "ARC-14653-2",
        patentNumber: "US9876543",
        imageURL: nil,
        center: "ARC",
        trl: "6"
    ))
    .environmentObject(PatentStore())
    .frame(width: 170)
    .padding()
}
