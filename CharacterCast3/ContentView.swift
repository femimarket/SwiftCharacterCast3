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

public struct ContentView: View {
    public init() {}

    @State private var mainFilename: String?
    @State private var targetFilename: String?
    @State private var targets: [URL] = []
    @State private var showingFileImporter = false
    @State private var showingPhotosPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var castCount = 0
    @State private var search = ""
    @State private var importError: String?
    @State private var showingResetConfirm = false

    private let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "webp", "gif", "tiff"]
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 100), spacing: 10)] }
    private var canCast: Bool { mainFilename != nil && targetFilename != nil }
    private var hasSelection: Bool { mainFilename != nil || targetFilename != nil }
    private var hasLibrary: Bool { !targets.isEmpty || mainFilename != nil }
    private var hasCast: Bool { castCount > 0 }

    private var filteredTargets: [URL] {
        guard !search.isEmpty else { return targets }
        return targets.filter {
            $0.lastPathComponent.localizedCaseInsensitiveContains(search)
        }
    }

    public var body: some View {
        Group {
            if hasLibrary {
                workingLayout
            } else {
                onboarding
            }
        }
        .navigationTitle("Cast")
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) { bottomBar }
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
        .confirmationDialog(
            "Reset selection?",
            isPresented: $showingResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive, action: resetAll)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clears the lead and target. Doesn’t delete any characters.")
        }
        .sensoryFeedback(.selection, trigger: targetFilename)
        .sensoryFeedback(.impact(weight: .light), trigger: mainFilename)
        .sensoryFeedback(.success, trigger: castCount)
        .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
        .task { await refreshTargets() }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if hasSelection {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset", role: .destructive) {
                    showingResetConfirm = true
                }
            }
        }
    }

    // MARK: Onboarding

    private var onboarding: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 18) {
                Image(systemName: "theatermasks.fill")
                    .font(.system(size: 64, weight: .light))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.tint, .secondary)
                VStack(spacing: 8) {
                    Text("Set up your cast")
                        .font(.title.weight(.semibold))
                    Text("Pick a lead. Choose who to wear.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            VStack(spacing: 10) {
                Button {
                    showingPhotosPicker = true
                } label: {
                    Label("Pick Lead from Photos", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: 320)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                Button {
                    showingFileImporter = true
                } label: {
                    Label("Pick Lead from Files", systemImage: "folder")
                        .frame(maxWidth: 320)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
            Text("Or drop an image anywhere on this screen.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: Working layout

    private var workingLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                pairSlots
                charactersSection
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .searchable(
            text: $search,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search characters"
        )
    }

    // MARK: Slots

    private var pairSlots: some View {
        HStack(spacing: 12) {
            leadSlot
            targetSlot
        }
    }

    private var leadSlot: some View {
        Menu {
            Button {
                showingPhotosPicker = true
            } label: {
                Label(mainFilename == nil ? "From Photos" : "Replace from Photos",
                      systemImage: "photo.on.rectangle")
            }
            Button {
                showingFileImporter = true
            } label: {
                Label(mainFilename == nil ? "From Files" : "Replace from Files",
                      systemImage: "folder")
            }
            if mainFilename != nil {
                Divider()
                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        mainFilename = nil
                        castCount = 0
                    }
                } label: {
                    Label("Remove Lead", systemImage: "trash")
                }
            }
        } label: {
            slotCard(
                filename: mainFilename,
                role: "LEAD",
                placeholderIcon: "person.crop.square.badge.plus",
                placeholderText: "Lead"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mainFilename.map { "Lead: \(displayName($0))" } ?? "Choose lead")
    }

    private var targetSlot: some View {
        Button {
            if targetFilename != nil {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    targetFilename = nil
                    castCount = 0
                }
            }
        } label: {
            slotCard(
                filename: targetFilename,
                role: "CAST AS",
                placeholderIcon: "person.crop.square",
                placeholderText: "Cast as"
            )
        }
        .buttonStyle(.plain)
        .disabled(targetFilename == nil)
        .accessibilityLabel(
            targetFilename.map { "Target: \(displayName($0)). Tap to clear." }
            ?? "Tap a character below to cast as."
        )
    }

    private func slotCard(
        filename: String?,
        role: String,
        placeholderIcon: String,
        placeholderText: String
    ) -> some View {
        Color.clear
            .aspectRatio(0.78, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay { slotContent(filename: filename, icon: placeholderIcon, text: placeholderText) }
            .overlay(alignment: .topLeading) {
                if filename != nil {
                    Text(role)
                        .font(.caption2.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.black.opacity(0.45)))
                        .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func slotContent(filename: String?, icon: String, text: String) -> some View {
        if let filename {
            ZStack(alignment: .bottom) {
                Thumbnail(url: ProjectService.getUrl(for: filename), maxPixelSize: 800)
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        } else {
            ZStack {
                Rectangle().fill(.regularMaterial)
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title.weight(.light))
                        .foregroundStyle(.secondary)
                    Text(text)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Characters

    private var charactersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Characters")
                    .font(.headline)
                Spacer()
                Text("\(filteredTargets.count)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            if filteredTargets.isEmpty {
                ContentUnavailableView.search(text: search)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredTargets, id: \.self) { url in
                        characterCell(url)
                    }
                }
            }
        }
    }

    private func characterCell(_ url: URL) -> some View {
        let name = url.lastPathComponent
        let isSelected = (name == targetFilename)
        let isLead = (name == mainFilename)

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                targetFilename = isSelected ? nil : name
                castCount = 0
            }
        } label: {
            Color.clear
                .aspectRatio(0.75, contentMode: .fit)
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
                        castCount = 0
                    }
                } label: {
                    Label("Use as Lead", systemImage: "crown")
                }
            }
            if isSelected {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        targetFilename = nil
                        castCount = 0
                    }
                } label: {
                    Label("Clear Selection", systemImage: "xmark.circle")
                }
            }
            Button(role: .destructive) {
                deleteCharacter(named: name)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityLabel(displayName(name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if canCast {
            HStack(spacing: 10) {
                if hasCast {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.green)
                        .symbolEffect(.bounce, value: castCount)
                        .padding(.leading, 4)
                        .accessibilityLabel("Args set")
                        .transition(.scale.combined(with: .opacity))
                }
                castButton
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: canCast)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: hasCast)
        }
    }

    private var castButton: some View {
        Button { triggerCast() } label: {
            Label("Cast", systemImage: "sparkles")
                .padding(.horizontal, 8)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }

    // MARK: Actions

    private func triggerCast() {
        guard let main = mainFilename, let target = targetFilename else { return }
        ProjectService.setCharacterCast(main, target)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            castCount += 1
        }
    }

    private func resetAll() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            mainFilename = nil
            targetFilename = nil
            castCount = 0
        }
    }

    private func deleteCharacter(named name: String) {
        let url = ProjectService.getUrl(for: name)
        try? FileManager.default.removeItem(at: url)
        if mainFilename == name { mainFilename = nil }
        if targetFilename == name { targetFilename = nil }
        castCount = 0
        Task { await refreshTargets() }
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
        defer { Task { @MainActor in photoItem = nil } }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run { importError = "Couldn’t load the selected photo." }
                return
            }
            await MainActor.run {
                ingest(data: data, suggestedStem: "photo")
            }
        } catch {
            await MainActor.run { importError = error.localizedDescription }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            if let data {
                let suggested = provider.suggestedName.map { "\($0).jpg" }
                Task { @MainActor in
                    ingest(data: data, originalName: suggested, suggestedStem: "drop")
                }
                return
            }
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { urlData, _ in
                guard let urlData,
                      let urlString = String(data: urlData, encoding: .utf8),
                      let url = URL(string: urlString)
                else { return }
                let needsScope = url.startAccessingSecurityScopedResource()
                defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
                guard let fileData = try? Data(contentsOf: url) else { return }
                Task { @MainActor in
                    ingest(data: fileData, originalName: url.lastPathComponent)
                }
            }
        }
    }

    private func ingest(data: Data, originalName: String? = nil, suggestedStem: String = "image") {
        let base = originalName ?? "\(suggestedStem)-\(UUID().uuidString.prefix(6)).jpg"
        let filename = uniqueFilename(for: base)
        ProjectService.saveFile(data, named: filename)
        mainFilename = filename
        castCount = 0
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

    private func refreshTargets() async {
        let exts = imageExts
        let result: [URL] = await Task.detached(priority: .utility) {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: docs,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { return [] }
            return urls
                .filter { exts.contains($0.pathExtension.lowercased()) }
                .sorted { lhs, rhs in
                    let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return l > r
                }
        }.value
        await MainActor.run { self.targets = result }
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
    NavigationStack { ContentView() }
        .tint(Color(red: 0.95, green: 0.25, blue: 0.55))
        .preferredColorScheme(.dark)
}
