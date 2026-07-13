import CoreGraphics
import Foundation

enum TerrainSurfaceKind: String, Sendable, Equatable {
    case windowTop
    case screenEdge
}

struct TerrainSurface: Sendable, Equatable, Identifiable {
    let id: String
    let kind: TerrainSurfaceKind
    let sourceBounds: CGRect
    let span: ClosedRange<CGFloat>
    let y: CGFloat
    let displayBounds: CGRect

    func contains(origin: CGPoint, tolerance: CGFloat = 2) -> Bool {
        span.contains(origin.x) && abs(origin.y - y) <= tolerance
    }

    func clampedX(_ x: CGFloat) -> CGFloat {
        min(max(x, span.lowerBound), span.upperBound)
    }
}

struct TerrainSnapshot: Sendable, Equatable {
    var surfaces: [TerrainSurface]

    var windowSurfaces: [TerrainSurface] {
        surfaces.filter { $0.kind == .windowTop }
    }

    var fallbackSurfaces: [TerrainSurface] {
        surfaces.filter { $0.kind == .screenEdge }
    }

    func surface(id: String) -> TerrainSurface? {
        surfaces.first { $0.id == id }
    }
}

struct WindowGeometryRecord: Sendable, Equatable {
    let id: UInt32
    let quartzBounds: CGRect
    let layer: Int
    let alpha: CGFloat
    let ownerPID: pid_t
}

@MainActor
protocol WindowTerrainProviding: AnyObject {
    func snapshot(petSize: CGSize) -> TerrainSnapshot
}

enum WindowTerrainBuilder {
    static let edgePadding: CGFloat = 12
    static let maximumTitleBarOverlap: CGFloat = 32
    static let minimumWindowSize = CGSize(width: 160, height: 80)

    static func appKitRect(fromQuartz rect: CGRect, primaryDisplayMaxY: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryDisplayMaxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func build(
        records: [WindowGeometryRecord],
        displays: [DisplayGeometry],
        primaryDisplayMaxY: CGFloat,
        petSize: CGSize,
        ownPID: pid_t
    ) -> TerrainSnapshot {
        let fallback = fallbackSurfaces(displays: displays, petSize: petSize)
        guard !displays.isEmpty else { return TerrainSnapshot(surfaces: fallback) }

        var surfaces: [TerrainSurface] = []
        var occluders: [CGRect] = []

        for record in records {
            guard record.ownerPID != ownPID, record.layer == 0, record.alpha > 0 else { continue }

            let rect = appKitRect(fromQuartz: record.quartzBounds, primaryDisplayMaxY: primaryDisplayMaxY)
            guard let display = bestDisplay(for: rect, displays: displays) else { continue }

            defer { occluders.append(rect) }
            let surfaceY = min(rect.maxY, display.visibleFrame.maxY - petSize.height)
            let titleBarOverlap = rect.maxY - surfaceY
            guard
                rect.width >= minimumWindowSize.width,
                rect.height >= minimumWindowSize.height,
                surfaceY >= display.visibleFrame.minY,
                titleBarOverlap <= maximumTitleBarOverlap
            else {
                continue
            }

            let visibleMinX = max(rect.minX, display.visibleFrame.minX)
            let visibleMaxX = min(rect.maxX, display.visibleFrame.maxX)
            var exposed = [visibleMinX...visibleMaxX]

            for occluder in occluders where occluder.minY <= surfaceY && occluder.maxY >= surfaceY {
                exposed = exposed.flatMap { subtract($0, by: occluder.minX...occluder.maxX) }
            }

            for (index, segment) in exposed.enumerated() {
                let lower = segment.lowerBound + edgePadding
                let upper = segment.upperBound - edgePadding - petSize.width
                guard upper >= lower else { continue }

                surfaces.append(TerrainSurface(
                    id: "window-\(record.id)-\(index)",
                    kind: .windowTop,
                    sourceBounds: rect,
                    span: lower...upper,
                    y: surfaceY,
                    displayBounds: display.visibleFrame
                ))
            }
        }

        return TerrainSnapshot(surfaces: surfaces + fallback)
    }

    private static func fallbackSurfaces(displays: [DisplayGeometry], petSize: CGSize) -> [TerrainSurface] {
        displays.enumerated().compactMap { index, display in
            let lower = display.visibleFrame.minX + edgePadding
            let upper = display.visibleFrame.maxX - edgePadding - petSize.width
            guard upper >= lower else { return nil }

            return TerrainSurface(
                id: "screen-edge-\(index)",
                kind: .screenEdge,
                sourceBounds: display.visibleFrame,
                span: lower...upper,
                y: display.visibleFrame.minY,
                displayBounds: display.visibleFrame
            )
        }
    }

    private static func bestDisplay(for rect: CGRect, displays: [DisplayGeometry]) -> DisplayGeometry? {
        displays
            .map { ($0, intersectionArea(rect, $0.frame)) }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }?
            .0
    }

    private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private static func subtract(
        _ source: ClosedRange<CGFloat>,
        by occlusion: ClosedRange<CGFloat>
    ) -> [ClosedRange<CGFloat>] {
        let lower = max(source.lowerBound, occlusion.lowerBound)
        let upper = min(source.upperBound, occlusion.upperBound)
        guard lower < upper else { return [source] }

        var result: [ClosedRange<CGFloat>] = []
        if source.lowerBound < lower {
            result.append(source.lowerBound...lower)
        }
        if upper < source.upperBound {
            result.append(upper...source.upperBound)
        }
        return result
    }
}
