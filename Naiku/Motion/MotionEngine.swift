import CoreGraphics
import Foundation

struct MotionConfiguration: Sendable, Equatable {
    var speed: CGFloat = 220
    var stoppingDistance: CGFloat = 22
}

struct MotionStep: Sendable, Equatable {
    let origin: CGPoint
    let direction: MovementDirection
    let isMoving: Bool
}

/// Pure movement math. All coordinates use AppKit's global display space:
/// origin at the lower-left of the primary display and positive Y pointing up.
enum MotionEngine {
    static func step(
        from origin: CGPoint,
        toward target: CGPoint,
        elapsed: TimeInterval,
        petSize: CGSize,
        within visibleBounds: CGRect,
        configuration: MotionConfiguration = MotionConfiguration()
    ) -> MotionStep {
        let safeElapsed = max(0, elapsed)
        let center = CGPoint(
            x: origin.x + petSize.width / 2,
            y: origin.y + petSize.height / 2
        )
        let dx = target.x - center.x
        let dy = target.y - center.y
        let distance = hypot(dx, dy)

        guard distance > configuration.stoppingDistance, distance > 0 else {
            return MotionStep(
                origin: clamp(origin: origin, petSize: petSize, to: visibleBounds),
                direction: .idle,
                isMoving: false
            )
        }

        let remainingDistance = distance - configuration.stoppingDistance
        let travel = min(configuration.speed * safeElapsed, remainingDistance)
        let proposed = CGPoint(
            x: origin.x + (dx / distance) * travel,
            y: origin.y + (dy / distance) * travel
        )

        return MotionStep(
            origin: clamp(origin: proposed, petSize: petSize, to: visibleBounds),
            direction: direction(dx: dx, dy: dy),
            isMoving: travel > 0
        )
    }

    static func direction(dx: CGFloat, dy: CGFloat) -> MovementDirection {
        guard dx != 0 || dy != 0 else { return .idle }

        let sector = Int((atan2(dy, dx) / (.pi / 4)).rounded())
        switch sector {
        case 0: return .east
        case 1: return .northEast
        case 2: return .north
        case 3: return .northWest
        case 4, -4: return .west
        case -3: return .southWest
        case -2: return .south
        case -1: return .southEast
        default: return .idle
        }
    }

    static func clamp(origin: CGPoint, petSize: CGSize, to bounds: CGRect) -> CGPoint {
        let maximumX = max(bounds.minX, bounds.maxX - petSize.width)
        let maximumY = max(bounds.minY, bounds.maxY - petSize.height)

        return CGPoint(
            x: min(max(origin.x, bounds.minX), maximumX),
            y: min(max(origin.y, bounds.minY), maximumY)
        )
    }
}
