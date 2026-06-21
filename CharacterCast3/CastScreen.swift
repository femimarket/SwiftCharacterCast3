//
//  CastScreen.swift
//  CharacterCast3
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import ProjectService

struct CastScreen: View {
    @State private var mainFilename: String?
    @State private var targetFilename: String?
    @State private var targets: [URL] = []
    @State private var showingImporter = false
    @State private var castPulse = false
    @State private var didCast = false

    private let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "webp", "gif", "tiff"]

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 104), spacing: 10)]
    }

    private var canCast: Bool {
        mainFilename != nil && targetFilename != nil
    }

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    mainCard
                    targetsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 160)
            }
            .scrollIndicators(.hidden)

            VStack {
                Spacer()
                castBar
            }
        }
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

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [
                    Color(red: 0.22, green: 0.08, blue: 0.36).opacity(0.55),
                    .black
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 520
            )
            RadialGradient(
                colors: [
                    Color(red: 0.95, green: 0.18, blue: 0.42).opacity(0.18),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CAST")
                .font(.system(size: 13, weight: .medium, design: .default))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.55))

            Text("Pick your lead.\nChoose who to wear.")
                .font(.system(size: 34, weight: .light, design: .default))
                .tracking(-0.5)
                .foregroundStyle(.white)
                .lineSpacing(2)
        }
        .padding(.top, 8)
    }

    // MARK: - Main character card

    private var mainCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showingImporter = true
        } label: {
            ZStack {
                if let main = mainFilename {
                    Thumbnail(url: ProjectService.getUrl(for: main), maxPixelSize: 1600)
                        .aspectRatio(1.18, contentMode: .fill)
                        .clipped()
                        .overlay {
                            LinearGradient(
                                colors: [.clear, .clear, .black.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .overlay(alignment: .topLeading) {
                            badge(text: "LEAD")
                                .padding(16)
                        }
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(main)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text("Tap to replace")
                                    .font(.system(size: 12, weight: .regular))
                                    .tracking(0.5)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .padding(18)
                        }
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [.white.opacity(0.08), .white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.05))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "person.crop.square")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            VStack(spacing: 4) {
                                Text("Choose lead")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundStyle(.white)
                                Text("Pick a portrait from Files")
                                    .font(.system(size: 12))
                                    .tracking(0.4)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                    .aspectRatio(1.18, contentMode: .fit)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.22),
                                .white.opacity(0.04),
                                .white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            }
            .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 16)
        }
        .buttonStyle(.plain)
    }

    private func badge(text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(2)
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(.white.opacity(0.92))
            )
    }

    // MARK: - Targets

    private var targetsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("CAST AS")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(3.5)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if !targets.isEmpty {
                    Text("\(targets.count)")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.4))
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
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                targetFilename = isSelected ? nil : name
                didCast = false
            }
        } label: {
            Thumbnail(url: url, maxPixelSize: 360)
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay {
                    if isSelected {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.45)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isLead {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(6)
                            .background(Circle().fill(.white.opacity(0.92)))
                            .padding(6)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(.white))
                            .padding(8)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isSelected
                                ? AnyShapeStyle(
                                    AngularGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.42, blue: 0.85),
                                            Color(red: 0.55, green: 0.42, blue: 1.0),
                                            Color(red: 0.4, green: 0.85, blue: 1.0),
                                            Color(red: 1.0, green: 0.42, blue: 0.85)
                                        ],
                                        center: .center
                                    )
                                )
                                : AnyShapeStyle(Color.white.opacity(0.08)),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                }
                .shadow(
                    color: isSelected
                        ? Color(red: 0.85, green: 0.35, blue: 0.85).opacity(0.55)
                        : .black.opacity(0.4),
                    radius: isSelected ? 18 : 8,
                    x: 0,
                    y: isSelected ? 6 : 4
                )
                .scaleEffect(isSelected ? 1.0 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var emptyTargets: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.stack")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.4))
            Text("No characters yet")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.55))
            Text("Drop images into the app's Documents folder.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.03))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.06), style: StrokeStyle(lineWidth: 0.6, dash: [4, 4]))
                }
        }
    }

    // MARK: - Cast bar

    private var castBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.85), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)
            .allowsHitTesting(false)

            castButton
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(Color.black)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var castButton: some View {
        Button {
            triggerCast()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: didCast ? "checkmark" : "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                Text(didCast ? "Cast set" : "Cast")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .foregroundStyle(canCast ? Color.black : Color.white.opacity(0.4))
            .background {
                ZStack {
                    if canCast {
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.85, blue: 0.95),
                                .white,
                                Color(red: 0.88, green: 0.92, blue: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        LinearGradient(
                            colors: [.white.opacity(0.7), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .blendMode(.plusLighter)
                    } else {
                        Color.white.opacity(0.06)
                    }
                }
            }
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(canCast ? 0.4 : 0.08), lineWidth: 0.6)
            }
            .shadow(
                color: canCast
                    ? Color(red: 0.85, green: 0.55, blue: 0.95).opacity(0.55)
                    : .clear,
                radius: 26,
                x: 0,
                y: 10
            )
            .scaleEffect(castPulse ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!canCast)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canCast)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: didCast)
    }

    private func triggerCast() {
        guard let main = mainFilename, let target = targetFilename else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeOut(duration: 0.08)) { castPulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { castPulse = false }
        }
        ProjectService.setCharacterCast(main, target)
        withAnimation(.easeOut(duration: 0.25)) { didCast = true }
    }

    // MARK: - Import / refresh

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
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { lhs, rhs in
                let l = (try? FileManager.default.attributesOfItem(atPath: lhs.path)[.modificationDate] as? Date) ?? .distantPast
                let r = (try? FileManager.default.attributesOfItem(atPath: rhs.path)[.modificationDate] as? Date) ?? .distantPast
                return l > r
            }
    }
}

#Preview {
    CastScreen()
}
