import CoreGraphics
import Foundation

struct PeripheralBehaviorConfiguration: Sendable, Equatable {
    var minimumIdleDuration: TimeInterval = 6
    var maximumIdleDuration: TimeInterval = 18
    var waitingAnimationDelay: TimeInterval = 2
    var flourishDuration: TimeInterval = 1.1
    var strollSpeed: CGFloat = 55
    var minimumStrollDistance: CGFloat = 40
    var maximumStrollDistance: CGFloat = 120
    var pointerInterestDuration: TimeInterval = 2
    var jumpHeight: CGFloat = 90
    var minimumJumpDuration: TimeInterval = 0.8
    var maximumJumpDuration: TimeInterval = 1.4
    var minimumFallbackDwellDuration: TimeInterval = 10
    var maximumFallbackDwellDuration: TimeInterval = 40
}

struct PeripheralDecisionValues: Sendable, Equatable {
    let action: Double
    let idleDuration: Double
    let distance: Double
    let direction: Double

    static func random() -> PeripheralDecisionValues {
        PeripheralDecisionValues(
            action: .random(in: 0..<1),
            idleDuration: .random(in: 0..<1),
            distance: .random(in: 0..<1),
            direction: .random(in: 0..<1)
        )
    }
}

struct JumpJourney: Sendable, Equatable {
    let targetSurfaceID: String
    let start: CGPoint
    let intendedEndX: CGFloat
    var elapsed: TimeInterval
    let duration: TimeInterval
}

enum PeripheralActivity: Sendable, Equatable {
    case unplaced
    case resting(surfaceID: String, remaining: TimeInterval, duration: TimeInterval)
    case flourishing(surfaceID: String, remaining: TimeInterval)
    case strolling(surfaceID: String, destinationX: CGFloat)
    case jumping(JumpJourney)

    var isStationary: Bool {
        switch self {
        case .resting, .flourishing:
            true
        case .unplaced, .strolling, .jumping:
            false
        }
    }
}

struct PeripheralBehaviorStep: Sendable, Equatable {
    let origin: CGPoint
    let renderState: PetRenderState
    let activity: PeripheralActivity
}

struct PeripheralBehaviorEngine: Sendable {
    let configuration: PeripheralBehaviorConfiguration
    private(set) var activity = PeripheralActivity.unplaced
    private(set) var pointerInterestSurfaceID: String?
    private(set) var pointerInterestElapsed: TimeInterval = 0
    private(set) var fallbackDwellElapsed: TimeInterval = 0
    private(set) var fallbackDwellLimit: TimeInterval?

    init(configuration: PeripheralBehaviorConfiguration = PeripheralBehaviorConfiguration()) {
        self.configuration = configuration
    }

    mutating func step(
        from origin: CGPoint,
        pointer: CGPoint,
        elapsed: TimeInterval,
        petSize: CGSize,
        terrain: TerrainSnapshot,
        decision: PeripheralDecisionValues
    ) -> PeripheralBehaviorStep {
        let safeElapsed = max(0, elapsed)
        updatePointerInterest(pointer: pointer, elapsed: safeElapsed, terrain: terrain)
        updateFallbackDwell(elapsed: safeElapsed, terrain: terrain, decision: decision)

        switch activity {
        case .unplaced:
            guard let surface = preferredSurface(in: terrain, near: origin) else {
                return result(origin: origin, renderState: .idle)
            }
            let placed = CGPoint(x: surface.clampedX(origin.x), y: surface.y)
            beginRest(on: surface.id, decision: decision)
            return result(origin: placed, renderState: .idle)

        case let .resting(surfaceID, remaining, duration):
            guard let surface = terrain.surface(id: surfaceID) else {
                return recover(from: origin, petSize: petSize, terrain: terrain, decision: decision)
            }
            let anchored = CGPoint(x: surface.clampedX(origin.x), y: surface.y)

            // A screen edge is a refuge, not a home: once the dwell allowance
            // runs out, any rest — nap included — is cut short in favour of a
            // nosier perch the moment a window top is available.
            if
                surface.kind == .screenEdge,
                let limit = fallbackDwellLimit,
                fallbackDwellElapsed >= limit,
                let perch = nearestWindowSurface(in: terrain, near: anchored)
            {
                return beginJump(from: anchored, to: perch, targetX: perch.clampedX(anchored.x))
            }

            let nextRemaining = remaining - safeElapsed
            guard nextRemaining <= 0 else {
                activity = .resting(surfaceID: surfaceID, remaining: nextRemaining, duration: duration)
                let hasSettled = duration - nextRemaining >= configuration.waitingAnimationDelay
                return result(origin: anchored, renderState: hasSettled ? .resting : .idle)
            }
            return chooseNextActivity(
                from: anchored,
                on: surface,
                pointer: pointer,
                petSize: petSize,
                terrain: terrain,
                decision: decision
            )

        case let .flourishing(surfaceID, remaining):
            guard let surface = terrain.surface(id: surfaceID) else {
                return recover(from: origin, petSize: petSize, terrain: terrain, decision: decision)
            }
            let anchored = CGPoint(x: surface.clampedX(origin.x), y: surface.y)
            let nextRemaining = remaining - safeElapsed
            if nextRemaining <= 0 {
                beginRest(on: surfaceID, decision: decision)
                return result(origin: anchored, renderState: .idle)
            }
            activity = .flourishing(surfaceID: surfaceID, remaining: nextRemaining)
            return result(origin: anchored, renderState: .flourishing)

        case let .strolling(surfaceID, destinationX):
            guard let surface = terrain.surface(id: surfaceID) else {
                return recover(from: origin, petSize: petSize, terrain: terrain, decision: decision)
            }
            let destination = surface.clampedX(destinationX)
            let currentX = surface.clampedX(origin.x)
            let dx = destination - currentX
            let travel = min(abs(dx), configuration.strollSpeed * safeElapsed)
            let nextX = currentX + (dx < 0 ? -travel : travel)
            let nextOrigin = CGPoint(x: nextX, y: surface.y)

            if travel >= abs(dx) {
                beginRest(on: surfaceID, decision: decision)
                return result(origin: nextOrigin, renderState: .idle)
            }
            activity = .strolling(surfaceID: surfaceID, destinationX: destination)
            return result(origin: nextOrigin, renderState: .moving(dx < 0 ? .west : .east))

        case var .jumping(journey):
            guard let target = terrain.surface(id: journey.targetSurfaceID) else {
                return recover(from: origin, petSize: petSize, terrain: terrain, decision: decision)
            }
            journey.elapsed += safeElapsed
            let end = CGPoint(x: target.clampedX(journey.intendedEndX), y: target.y)
            let progress = min(1, journey.elapsed / journey.duration)
            let nextOrigin = Self.jumpPoint(
                from: journey.start,
                to: end,
                progress: progress,
                height: configuration.jumpHeight
            )

            if progress >= 1 {
                beginRest(on: target.id, decision: decision)
                return result(origin: end, renderState: .idle)
            }
            activity = .jumping(journey)
            return result(origin: nextOrigin, renderState: .jumping)
        }
    }

    static func jumpPoint(
        from start: CGPoint,
        to end: CGPoint,
        progress: Double,
        height: CGFloat
    ) -> CGPoint {
        let t = CGFloat(min(max(progress, 0), 1))
        let inverse = 1 - t
        let apexLift = max(height, abs(end.x - start.x) * 0.12)
        let control = CGPoint(
            x: (start.x + end.x) / 2,
            y: max(start.y, end.y) + 2 * apexLift + abs(end.y - start.y) / 2
        )
        return CGPoint(
            x: inverse * inverse * start.x + 2 * inverse * t * control.x + t * t * end.x,
            y: inverse * inverse * start.y + 2 * inverse * t * control.y + t * t * end.y
        )
    }

    private mutating func chooseNextActivity(
        from origin: CGPoint,
        on surface: TerrainSurface,
        pointer: CGPoint,
        petSize: CGSize,
        terrain: TerrainSnapshot,
        decision: PeripheralDecisionValues
    ) -> PeripheralBehaviorStep {
        let action = normalized(decision.action)

        // Deliberately explicit bands make pointer curiosity only one mood
        // among several, instead of the default destination for most choices.
        if action < 0.18 || action >= 0.92 {
            beginNap(on: surface.id, decision: decision)
            return result(origin: origin, renderState: .resting)
        }

        if action < 0.32 {
            activity = .flourishing(surfaceID: surface.id, remaining: configuration.flourishDuration)
            return result(origin: origin, renderState: .flourishing)
        }

        if action < 0.66 {
            return beginIndependentStroll(from: origin, on: surface, decision: decision)
        }

        if action < 0.78 {
            let alternatives = terrain.windowSurfaces.filter { $0.id != surface.id }
            guard !alternatives.isEmpty else {
                return beginIndependentStroll(from: origin, on: surface, decision: decision)
            }
            let targetIndex = min(
                Int(normalized(decision.distance) * CGFloat(alternatives.count)),
                alternatives.count - 1
            )
            let target = alternatives[targetIndex]
            let targetX = target.span.lowerBound
                + (target.span.upperBound - target.span.lowerBound) * normalized(decision.distance)
            return beginJump(from: origin, to: target, targetX: targetX)
        }

        if action < 0.90 {
            guard pointerInterestElapsed >= configuration.pointerInterestDuration else {
                return beginIndependentStroll(from: origin, on: surface, decision: decision)
            }

            if
                let interestedID = pointerInterestSurfaceID,
                interestedID != surface.id,
                let target = terrain.surface(id: interestedID)
            {
                let offset: CGFloat = normalized(decision.direction) < 0.5 ? -32 : 32
                let targetX = target.clampedX(pointer.x - petSize.width / 2 + offset)
                return beginJump(from: origin, to: target, targetX: targetX)
            }

            if pointerInterestSurfaceID == surface.id {
                let offset: CGFloat = normalized(decision.direction) < 0.5 ? -32 : 32
                let desired = pointer.x - petSize.width / 2 + offset
                let delta = min(
                    max(desired - origin.x, -configuration.maximumStrollDistance),
                    configuration.maximumStrollDistance
                )
                return beginStroll(
                    from: origin,
                    on: surface,
                    proposedDestination: origin.x + delta,
                    decision: decision
                )
            }

            return beginIndependentStroll(from: origin, on: surface, decision: decision)
        }

        // The narrow gap between explicit mood bands is an ordinary settle,
        // which is a safe fallback at probability boundaries.
        beginRest(on: surface.id, decision: decision)
        return result(origin: origin, renderState: .resting)
    }

    private mutating func beginIndependentStroll(
        from origin: CGPoint,
        on surface: TerrainSurface,
        decision: PeripheralDecisionValues
    ) -> PeripheralBehaviorStep {
        let distance = configuration.minimumStrollDistance
            + (configuration.maximumStrollDistance - configuration.minimumStrollDistance) * normalized(decision.distance)
        let sign: CGFloat = normalized(decision.direction) < 0.5 ? -1 : 1
        return beginStroll(
            from: origin,
            on: surface,
            proposedDestination: origin.x + sign * distance,
            decision: decision
        )
    }

    private mutating func beginStroll(
        from origin: CGPoint,
        on surface: TerrainSurface,
        proposedDestination: CGFloat,
        decision: PeripheralDecisionValues
    ) -> PeripheralBehaviorStep {
        let distance = configuration.minimumStrollDistance
            + (configuration.maximumStrollDistance - configuration.minimumStrollDistance) * normalized(decision.distance)
        var destination = surface.clampedX(proposedDestination)

        if abs(destination - origin.x) < configuration.minimumStrollDistance / 2 {
            let opposite = destination <= origin.x ? 1.0 : -1.0
            destination = surface.clampedX(origin.x + CGFloat(opposite) * distance)
        }

        guard abs(destination - origin.x) >= 1 else {
            beginRest(on: surface.id, decision: decision)
            return result(origin: origin, renderState: .resting)
        }

        activity = .strolling(surfaceID: surface.id, destinationX: destination)
        return result(origin: origin, renderState: .moving(destination < origin.x ? .west : .east))
    }

    private mutating func recover(
        from origin: CGPoint,
        petSize: CGSize,
        terrain: TerrainSnapshot,
        decision: PeripheralDecisionValues
    ) -> PeripheralBehaviorStep {
        guard let target = preferredSurface(in: terrain, near: origin) else {
            activity = .unplaced
            return result(origin: origin, renderState: .idle)
        }
        let targetX = target.clampedX(origin.x)
        let end = CGPoint(x: targetX, y: target.y)
        if hypot(end.x - origin.x, end.y - origin.y) < 1 {
            beginRest(on: target.id, decision: decision)
            return result(origin: end, renderState: .idle)
        }
        return beginJump(from: origin, to: target, targetX: targetX)
    }

    private mutating func beginJump(
        from origin: CGPoint,
        to target: TerrainSurface,
        targetX: CGFloat
    ) -> PeripheralBehaviorStep {
        let end = CGPoint(x: target.clampedX(targetX), y: target.y)
        let distance = hypot(end.x - origin.x, end.y - origin.y)
        let proposedDuration = 0.6 + TimeInterval(distance / 500)
        let duration = min(max(proposedDuration, configuration.minimumJumpDuration), configuration.maximumJumpDuration)
        let journey = JumpJourney(
            targetSurfaceID: target.id,
            start: origin,
            intendedEndX: end.x,
            elapsed: 0,
            duration: duration
        )
        activity = .jumping(journey)
        return result(origin: origin, renderState: .jumping)
    }

    private mutating func beginRest(on surfaceID: String, decision: PeripheralDecisionValues) {
        let duration = configuration.minimumIdleDuration
            + (configuration.maximumIdleDuration - configuration.minimumIdleDuration) * normalized(decision.idleDuration)
        activity = .resting(surfaceID: surfaceID, remaining: duration, duration: duration)
    }

    private mutating func beginNap(on surfaceID: String, decision: PeripheralDecisionValues) {
        let minimumNapDuration = max(
            configuration.maximumIdleDuration + 1,
            configuration.maximumIdleDuration * 1.5
        )
        let maximumNapDuration = max(minimumNapDuration, configuration.maximumIdleDuration * 2.5)
        let duration = minimumNapDuration
            + (maximumNapDuration - minimumNapDuration) * TimeInterval(normalized(decision.idleDuration))
        activity = .resting(surfaceID: surfaceID, remaining: duration, duration: duration)
    }

    private mutating func updatePointerInterest(
        pointer: CGPoint,
        elapsed: TimeInterval,
        terrain: TerrainSnapshot
    ) {
        let candidate = terrain.windowSurfaces.first { $0.sourceBounds.contains(pointer) }?.id
        if candidate == pointerInterestSurfaceID {
            pointerInterestElapsed += elapsed
        } else {
            pointerInterestSurfaceID = candidate
            pointerInterestElapsed = candidate == nil ? 0 : elapsed
        }
    }

    private mutating func updateFallbackDwell(
        elapsed: TimeInterval,
        terrain: TerrainSnapshot,
        decision: PeripheralDecisionValues
    ) {
        let anchoredKind = anchoredSurfaceID.flatMap { terrain.surface(id: $0) }?.kind
        guard anchoredKind == .screenEdge else {
            fallbackDwellElapsed = 0
            fallbackDwellLimit = nil
            return
        }
        if fallbackDwellLimit == nil {
            fallbackDwellLimit = configuration.minimumFallbackDwellDuration
                + (configuration.maximumFallbackDwellDuration - configuration.minimumFallbackDwellDuration)
                * TimeInterval(normalized(decision.idleDuration))
        }
        fallbackDwellElapsed += elapsed
    }

    private var anchoredSurfaceID: String? {
        switch activity {
        case .unplaced:
            nil
        case let .resting(surfaceID, _, _):
            surfaceID
        case let .flourishing(surfaceID, _):
            surfaceID
        case let .strolling(surfaceID, _):
            surfaceID
        case let .jumping(journey):
            journey.targetSurfaceID
        }
    }

    private func nearestWindowSurface(in terrain: TerrainSnapshot, near point: CGPoint) -> TerrainSurface? {
        terrain.windowSurfaces.min {
            distanceSquared(from: point, to: $0) < distanceSquared(from: point, to: $1)
        }
    }

    private func preferredSurface(in terrain: TerrainSnapshot, near point: CGPoint) -> TerrainSurface? {
        let candidates = terrain.windowSurfaces.isEmpty ? terrain.fallbackSurfaces : terrain.windowSurfaces
        return candidates.min {
            distanceSquared(from: point, to: $0) < distanceSquared(from: point, to: $1)
        }
    }

    private func distanceSquared(from point: CGPoint, to surface: TerrainSurface) -> CGFloat {
        let x = surface.clampedX(point.x)
        return pow(point.x - x, 2) + pow(point.y - surface.y, 2)
    }

    private func result(origin: CGPoint, renderState: PetRenderState) -> PeripheralBehaviorStep {
        PeripheralBehaviorStep(origin: origin, renderState: renderState, activity: activity)
    }

    private func normalized(_ value: Double) -> CGFloat {
        CGFloat(min(max(value, 0), 1))
    }
}
