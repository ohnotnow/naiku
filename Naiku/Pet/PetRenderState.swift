enum PetRenderState: Equatable, Sendable {
    case idle
    case resting
    case flourishing
    case moving(MovementDirection)
    case jumping

    var animationID: PetAnimationID {
        switch self {
        case .idle:
            .idle
        case .resting:
            .waiting
        case .flourishing:
            .waving
        case .jumping:
            .jumping
        case .moving(.east), .moving(.northEast), .moving(.southEast):
            .runningRight
        case .moving(.west), .moving(.northWest), .moving(.southWest):
            .runningLeft
        case .moving(.north), .moving(.south), .moving(.idle):
            .running
        }
    }
}
