import CoreGraphics
import Foundation

struct DirectChatIntentTracker: Sendable, Equatable {
    var dwellDuration: TimeInterval = 0.5
    var movementThreshold: CGFloat = 0.5

    private(set) var isArmed = false
    private var isDwelling = false
    private var dwellElapsed: TimeInterval = 0
    private var previousPointer: CGPoint?
    private var previousPetOrigin: CGPoint?
    private var previousPointerWasOnCat = false

    init(dwellDuration: TimeInterval = 0.5, movementThreshold: CGFloat = 0.5) {
        self.dwellDuration = dwellDuration
        self.movementThreshold = movementThreshold
    }

    mutating func update(
        pointer: CGPoint,
        petOrigin: CGPoint,
        isPointerOnCat: Bool,
        isPetStationary: Bool,
        elapsed: TimeInterval
    ) -> Bool {
        guard let previousPointer, let previousPetOrigin else {
            remember(pointer: pointer, petOrigin: petOrigin, isPointerOnCat: isPointerOnCat)
            return false
        }

        let pointerMoved = hypot(
            pointer.x - previousPointer.x,
            pointer.y - previousPointer.y
        ) > movementThreshold
        let petMoved = hypot(
            petOrigin.x - previousPetOrigin.x,
            petOrigin.y - previousPetOrigin.y
        ) > movementThreshold

        defer {
            remember(pointer: pointer, petOrigin: petOrigin, isPointerOnCat: isPointerOnCat)
        }

        guard isPetStationary, !petMoved, isPointerOnCat else {
            disarmDwell()
            return false
        }

        if isArmed {
            return true
        }

        if !isDwelling {
            // An eligible dwell starts only when the pointer crosses onto a
            // stationary Naiku. Naiku walking under an unmoved pointer is not
            // treated as an invitation to intercept the user's next click.
            guard !previousPointerWasOnCat, pointerMoved else { return false }
            isDwelling = true
            dwellElapsed = 0
            return false
        }

        dwellElapsed += max(0, elapsed)
        if dwellElapsed >= dwellDuration {
            isArmed = true
        }
        return isArmed
    }

    mutating func reset() {
        isArmed = false
        isDwelling = false
        dwellElapsed = 0
        previousPointer = nil
        previousPetOrigin = nil
        previousPointerWasOnCat = false
    }

    private mutating func disarmDwell() {
        isArmed = false
        isDwelling = false
        dwellElapsed = 0
    }

    private mutating func remember(
        pointer: CGPoint,
        petOrigin: CGPoint,
        isPointerOnCat: Bool
    ) {
        previousPointer = pointer
        previousPetOrigin = petOrigin
        previousPointerWasOnCat = isPointerOnCat
    }
}
