import Foundation

enum PetRenderState: Equatable, Sendable {
    case idle
    case moving(MovementDirection)
    case resting

    var animationID: PetAnimationID {
        switch self {
        case .idle:
            .idle
        case .resting:
            .waiting
        case .moving(.east), .moving(.northEast), .moving(.southEast):
            .runningRight
        case .moving(.west), .moving(.northWest), .moving(.southWest):
            .runningLeft
        case .moving(.north), .moving(.south), .moving(.idle):
            .running
        }
    }
}

struct PetBehaviorStateMachine: Sendable {
    static let restingDelay: TimeInterval = 4

    private(set) var state = PetRenderState.idle
    private var stationaryDuration: TimeInterval = 0

    mutating func update(
        direction: MovementDirection,
        isMoving: Bool,
        elapsed: TimeInterval
    ) -> PetRenderState {
        if isMoving, direction != .idle {
            stationaryDuration = 0
            state = .moving(direction)
        } else {
            stationaryDuration += max(0, elapsed)
            state = stationaryDuration >= Self.restingDelay ? .resting : .idle
        }
        return state
    }

    mutating func reset() {
        stationaryDuration = 0
        state = .idle
    }
}
