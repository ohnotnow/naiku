import AppKit
import ImageIO

enum PetAnimationID: String, Codable, CaseIterable, Sendable {
    case idle
    case runningRight = "running-right"
    case runningLeft = "running-left"
    case waving
    case jumping
    case failed
    case waiting
    case running
    case review
}

struct PetAnimation: Codable, Equatable, Sendable {
    let row: Int
    let frameDurations: [Int]

    var frameCount: Int { frameDurations.count }
}

struct PetAnimationManifest: Codable, Equatable, Sendable {
    let atlasWidth: Int
    let atlasHeight: Int
    let cellWidth: Int
    let cellHeight: Int
    let animations: [String: PetAnimation]

    func animation(_ id: PetAnimationID) -> PetAnimation? {
        animations[id.rawValue]
    }

    func sourceRect(for id: PetAnimationID, frameIndex: Int) -> NSRect? {
        guard let animation = animation(id), !animation.frameDurations.isEmpty else { return nil }
        let column = frameIndex % animation.frameCount
        return NSRect(
            x: column * cellWidth,
            y: atlasHeight - ((animation.row + 1) * cellHeight),
            width: cellWidth,
            height: cellHeight
        )
    }
}

struct PetAnimationLibrary {
    let image: NSImage
    let manifest: PetAnimationManifest

    static func bundled(in bundle: Bundle = .main) -> PetAnimationLibrary? {
        guard
            let imageURL = bundle.url(forResource: "NaikuSpritesheet", withExtension: "png"),
            let manifestURL = bundle.url(forResource: "NaikuAnimations", withExtension: "json"),
            let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(
                imageSource,
                0,
                [
                    kCGImageSourceShouldCache: true,
                    kCGImageSourceShouldCacheImmediately: true,
                ] as CFDictionary
            ),
            let data = try? Data(contentsOf: manifestURL),
            let manifest = try? JSONDecoder().decode(PetAnimationManifest.self, from: data)
        else {
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        bitmap.size = NSSize(width: cgImage.width, height: cgImage.height)
        let image = NSImage(size: bitmap.size)
        image.cacheMode = .never
        image.addRepresentation(bitmap)
        return PetAnimationLibrary(image: image, manifest: manifest)
    }
}
