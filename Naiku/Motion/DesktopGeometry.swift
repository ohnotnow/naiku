import AppKit

struct DisplayGeometry: Sendable, Equatable {
    let frame: CGRect
    let visibleFrame: CGRect
}

enum DesktopGeometry {
    @MainActor
    static var currentDisplays: [DisplayGeometry] {
        NSScreen.screens.map { DisplayGeometry(frame: $0.frame, visibleFrame: $0.visibleFrame) }
    }

    @MainActor
    static func visibleBounds(containing point: CGPoint) -> CGRect {
        visibleBounds(
            containing: point,
            displays: currentDisplays,
            fallback: NSScreen.main?.visibleFrame ?? .zero
        )
    }

    static func visibleBounds(
        containing point: CGPoint,
        displays: [DisplayGeometry],
        fallback: CGRect
    ) -> CGRect {
        displays.first(where: { $0.frame.contains(point) })?.visibleFrame ?? fallback
    }

    static func nearestVisibleBounds(
        to rect: CGRect,
        displays: [DisplayGeometry],
        fallback: CGRect
    ) -> CGRect {
        guard !displays.isEmpty else { return fallback }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        return displays.min { lhs, rhs in
            distanceSquared(from: center, to: lhs.frame) < distanceSquared(from: center, to: rhs.frame)
        }?.visibleFrame ?? fallback
    }

    static func clampedOrigin(_ origin: CGPoint, petSize: CGSize, to bounds: CGRect) -> CGPoint {
        let maximumX = max(bounds.minX, bounds.maxX - petSize.width)
        let maximumY = max(bounds.minY, bounds.maxY - petSize.height)

        return CGPoint(
            x: min(max(origin.x, bounds.minX), maximumX),
            y: min(max(origin.y, bounds.minY), maximumY)
        )
    }

    private static func distanceSquared(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let closestX = min(max(point.x, rect.minX), rect.maxX)
        let closestY = min(max(point.y, rect.minY), rect.maxY)
        return pow(point.x - closestX, 2) + pow(point.y - closestY, 2)
    }
}
