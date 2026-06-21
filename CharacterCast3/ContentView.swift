//
//  ContentView.swift
//  CharacterCast3
//
//  Created by u on 21/06/2026.
//

import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import PhotosUI
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
    @State private var showingFileImporter = false
    @State private var showingPhotosPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var didCast = false
    @State private var search = ""
    @State private var importError: String?

    private let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "webp", "gif", "tiff"]
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 104), spacing: 10)] }
    private var canCast: Bool { mainFilename != nil && targetFilename != nil }
    private var hasSelection: Bool { mainFilename != nil || targetFilename != nil }

    private var filteredTargets: [URL] {
        guard !search.isEmpty else { return targets }
        return targets.filter {
            $0.lastPathComponent.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard
                    targetsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .refreshable { await refreshTargets() }
            .navigationTitle("Cast")
            .searchable(
                text: $search,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search characters"
            )
            .toolbar {
                if hasSelection {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Reset", role: .destructive, action: resetAll)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .tint(Color(red: 0.95, green: 0.25, blue: 0.55))
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .photosPicker(
            isPresented: $showingPhotosPicker,
            selection: $photoItem,
            matching: .images
        )
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await handlePhotoItem(item) }
        }
        .alert(
            "Couldn’t Import",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            ),
            presenting: importError
        ) { _ in
            Button("OK") { importError = nil }
        } message: { message in
            Text(message)
        }
        .sensoryFeedback(.selection, trigger: targetFilename)
        .sensoryFeedback(.impact(weight: .light), trigger: mainFilename)
        .sensoryFeedback(.success, trigger: didCast)
        .task { await refreshTargets() }
    }

    // MARK: Hero

    private var heroCard: some View {
        Menu {
            Button {
                showingFileImporter = true
            } label: {
                Label("Choose from Files", systemImage: "folder")
            }
            Button {
                showingPhotosPicker = true
            } label: {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
            }
            if mainFilename != nil {
                Divider()
                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        mainFilename = nil
                        didCast = false
                    }
                } label: {
                    Label("Remove Lead", systemImage: "trash")
                }
            }
        } label: {
            Color.clear
                .aspectRatio(0.95, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay { heroContent }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mainFilename == nil ? "Choose lead character" : "Lead character options")
        .dropDestination(for: Data.self) { items, _ in
            guard let data = items.first else { return false }
            ingest(data: data, suggestedStem: "lead")
            return true
        }
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
                Text(displayName(main))
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
                    Text("Pick a portrait, or drop one here")
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
                    Text("\(filteredTargets.count)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }

            if targets.isEmpty {
                ContentUnavailableView(
                    "No Characters",
                    systemImage: "photo.stack",
                    description: Text("Drop images into the app’s Documents folder to cast.")
                )
                .frame(maxWidth: .infinity)
            } else if filteredTargets.isEmpty {
                ContentUnavailableView.search(text: search)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredTargets, id: \.self) { url in
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
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                targetFilename = isSelected ? nil : name
                didCast = false
            }
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay { Thumbnail(url: url, maxPixelSize: 360) }
                .overlay(alignment: .topTrailing) {
                    if isLead && !isSelected {
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
                            .symbolEffect(.bounce, value: isSelected)
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
        .contextMenu {
            if !isLead {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        mainFilename = name
                        if targetFilename == name { targetFilename = nil }
                        didCast = false
                    }
                } label: {
                    Label("Use as Lead", systemImage: "crown")
                }
            }
            if isSelected {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        targetFilename = nil
                        didCast = false
                    }
                } label: {
                    Label("Clear Selection", systemImage: "xmark.circle")
                }
            }
        }
        .accessibilityLabel(displayName(name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if canCast, let main = mainFilename, let target = targetFilename {
            VStack(spacing: 12) {
                pairPreview(main: main, target: target)
                castButton
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: canCast)
        }
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
                    .symbolEffect(.bounce, value: didCast)
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
                .contentTransition(.symbolEffect(.replace))
                .padding(.horizontal, 8)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(didCast)
    }

    // MARK: Actions

    private func triggerCast() {
        guard let main = mainFilename, let target = targetFilename else { return }
        ProjectService.setCharacterCast(main, target)
        withAnimation(.easeOut(duration: 0.25)) { didCast = true }
    }

    private func resetAll() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            mainFilename = nil
            targetFilename = nil
            didCast = false
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            guard let picked = urls.first else { return }
            let needsScope = picked.startAccessingSecurityScopedResource()
            defer { if needsScope { picked.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: picked)
                ingest(data: data, originalName: picked.lastPathComponent)
            } catch {
                importError = "Couldn’t read the selected file."
            }
        }
    }

    private func handlePhotoItem(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                importError = "Couldn’t load the selected photo."
                return
            }
            await MainActor.run {
                ingest(data: data, suggestedStem: "lead")
            }
        } catch {
            await MainActor.run { importError = error.localizedDescription }
        }
    }

    private func ingest(data: Data, originalName: String? = nil, suggestedStem: String = "image") {
        let base = originalName ?? "\(suggestedStem)-\(UUID().uuidString.prefix(6)).jpg"
        let filename = uniqueFilename(for: base)
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
        let suffix = UUID().uuidString.prefix(6)
        return ext.isEmpty ? "\(stem)-\(suffix)" : "\(stem)-\(suffix).\(ext)"
    }

    private func displayName(_ filename: String) -> String {
        let url = URL(fileURLWithPath: filename)
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let cleanedStem: String
        if let range = stem.range(of: "-[0-9A-Fa-f]{6}$", options: .regularExpression) {
            cleanedStem = String(stem[..<range.lowerBound])
        } else {
            cleanedStem = stem
        }
        return ext.isEmpty ? cleanedStem : "\(cleanedStem).\(ext)"
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
