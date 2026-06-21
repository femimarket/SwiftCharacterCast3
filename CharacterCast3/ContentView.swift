//
//  ContentView.swift
//  CharacterCast3
//
//  Created by u on 21/06/2026.
//

import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers
import ProjectService

struct ContentView: View {
    var body: some View {
        CastScreen()
    }
}

// MARK: - Cast screen

struct CastScreen: View {
    @State private var mainFilename: String?
    @State private var targetFilename: String?
    @State private var targets: [URL] = []
    @State private var showingImporter = false
    @State private var didCast = false

    private let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "webp", "gif", "tiff"]
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 104), spacing: 10)] }
    private var canCast: Bool { mainFilename != nil && targetFilename != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    targetsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .refreshable { await refreshTargets() }
            .navigationTitle("Cast")
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .tint(Color(red: 0.95, green: 0.25, blue: 0.55))
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .task { await refreshTargets() }
    }

    // MARK: Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lead")
                .font(.headline)
            heroCard
        }
    }

    private var heroCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showingImporter = true
        } label: {
            Color.clear
                .aspectRatio(0.86, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay { heroContent }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mainFilename == nil ? "Choose lead character" : "Replace lead character")
    }

    @ViewBuilder
    private var heroContent: some View {
        if let main = mainFilename {
            ZStack(alignment: .bottomLeading) {
                Thumbnail(url: ProjectService.getUrl(for: main), maxPixelSize: 1600)
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )
                Text(main)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding()
            }
        } else {
            ZStack {
                Rectangle().fill(.regularMaterial)
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.square.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Choose Lead")
                        .font(.headline)
                    Text("Pick a portrait from Files")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Targets

    private var targetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Cast As")
                    .font(.headline)
                Spacer()
                if !targets.isEmpty {
                    Text("\(targets.count)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if targets.isEmpty {
                emptyTargets
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(targets, id: \.self) { url in
                        targetCell(url)
                    }
                }
            }
        }
    }

    private func targetCell(_ url: URL) -> some View {
        let name = url.lastPathComponent
        let isSelected = (name == targetFilename)
        let isLead = (name == mainFilename)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                targetFilename = isSelected ? nil : name
                didCast = false
            }
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay { Thumbnail(url: url, maxPixelSize: 360) }
                .overlay(alignment: .topTrailing) {
                    if isLead {
                        Image(systemName: "crown.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.primary)
                            .padding(5)
                            .background(Circle().fill(.regularMaterial))
                            .padding(6)
                            .accessibilityLabel("Lead")
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .tint)
                            .padding(6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var emptyTargets: some View {
        ContentUnavailableView(
            "No Characters",
            systemImage: "photo.stack",
            description: Text("Drop images into the app's Documents folder to cast.")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if let main = mainFilename, let target = targetFilename {
                pairPreview(main: main, target: target)
            }
            castButton
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func pairPreview(main: String, target: String) -> some View {
        HStack(spacing: 10) {
            roundPreview(name: main)
            Image(systemName: "arrow.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            roundPreview(name: target)
            if didCast {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.green)
                    .padding(.leading, 2)
                    .padding(.trailing, 4)
                    .accessibilityLabel("Args set")
            }
        }
        .padding(8)
        .glassEffect(.regular, in: Capsule())
    }

    private func roundPreview(name: String) -> some View {
        Thumbnail(url: ProjectService.getUrl(for: name), maxPixelSize: 160)
            .frame(width: 32, height: 32)
            .clipShape(Circle())
    }

    private var castButton: some View {
        Button { triggerCast() } label: {
            Label(didCast ? "Cast set" : "Cast",
                  systemImage: didCast ? "checkmark" : "sparkles")
                .padding(.horizontal, 8)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(!canCast)
    }

    // MARK: Actions

    private func triggerCast() {
        guard let main = mainFilename, let target = targetFilename else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        ProjectService.setCharacterCast(main, target)
        withAnimation(.easeOut(duration: 0.25)) { didCast = true }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let picked = urls.first else { return }
        let needsScope = picked.startAccessingSecurityScopedResource()
        defer { if needsScope { picked.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: picked) else { return }
        let filename = uniqueFilename(for: picked.lastPathComponent)
        ProjectService.saveFile(data, named: filename)
        mainFilename = filename
        didCast = false
        Task { await refreshTargets() }
    }

    private func uniqueFilename(for original: String) -> String {
        let existing = Set(targets.map { $0.lastPathComponent })
        if !existing.contains(original) { return original }
        let url = URL(fileURLWithPath: original)
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var i = 2
        while true {
            let candidate = ext.isEmpty ? "\(stem) \(i)" : "\(stem) \(i).\(ext)"
            if !existing.contains(candidate) { return candidate }
            i += 1
        }
    }

    @MainActor
    private func refreshTargets() async {
        let all = ProjectService.getAllGenerations()
        targets = all
            .filter { imageExts.contains($0.pathExtension.lowercased()) }
            .sorted { lhs, rhs in
                let l = (try? FileManager.default.attributesOfItem(atPath: lhs.path)[.modificationDate] as? Date) ?? .distantPast
                let r = (try? FileManager.default.attributesOfItem(atPath: rhs.path)[.modificationDate] as? Date) ?? .distantPast
                return l > r
            }
    }
}

// MARK: - Thumbnail (lazy, cached, downsampled)

private actor ThumbnailLoader {
    static let shared = ThumbnailLoader()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 600
        return c
    }()

    func thumbnail(for url: URL, maxPixelSize: Int) async -> UIImage? {
        let key = "\(url.path)|\(maxPixelSize)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let image = UIImage(cgImage: cg)
        cache.setObject(image, forKey: key)
        return image
    }
}

private struct Thumbnail: View {
    let url: URL
    let maxPixelSize: Int
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .task(id: url) {
            image = await ThumbnailLoader.shared.thumbnail(for: url, maxPixelSize: maxPixelSize)
        }
    }
}

#Preview {
    ContentView()
}
