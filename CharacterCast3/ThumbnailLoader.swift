//
//  ThumbnailLoader.swift
//  CharacterCast3
//

import UIKit
import ImageIO
import SwiftUI

actor ThumbnailLoader {
    static let shared = ThumbnailLoader()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 600
        return c
    }()

    func thumbnail(for url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        let key = "\(url.path)|\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key)
        return image
    }
}

struct Thumbnail: View {
    let url: URL
    let maxPixelSize: CGFloat
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                LinearGradient(
                    colors: [.white.opacity(0.05), .white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .task(id: url) {
            image = await ThumbnailLoader.shared.thumbnail(for: url, maxPixelSize: maxPixelSize)
        }
    }
}
