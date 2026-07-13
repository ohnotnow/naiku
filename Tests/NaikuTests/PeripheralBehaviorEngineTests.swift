import CoreGraphics
import XCTest
@testable import Naiku

final class PeripheralBehaviorEngineTests: XCTestCase {
    private let petSize = CGSize(width: 72, height: 72)

    func testStationaryPointerDoesNotPullNaikuDuringIdle() {
        var engine = PeripheralBehaviorEngine(configuration: configuration(idle: 6))
        let terrain = TerrainSnapshot(surfaces: [sourceSurface])
        let pointer = CGPoint(x: 180, y: 100)

        var step = engine.step(
            from: CGPoint(x: 100, y: 20),
            pointer: pointer,
            elapsed: 0,
            petSize: petSize,
            terrain: terrain,
            decision: decision()
        )
        let placedOrigin = step.origin

        for _ in 0..<5 {
            step = engine.step(
                from: step.origin,
                pointer: pointer,
                elapsed: 1,
                petSize: petSize,
                terrain: terrain,
                decision: decision(action: 0.7)
            )
        }

        XCTAssertEqual(step.origin, placedOrigin)
        XCTAssertNotEqual(step.origin.x + petSize.width / 2, pointer.x)
        XCTAssertEqual(step.renderState, .resting)
    }

    func testLocalStrollIsShortHorizontalAndCannotBeRetargetedMidStep() {
        var engine = PeripheralBehaviorEngine(configuration: configuration(idle: 1))
        let terrain = TerrainSnapshot(surfaces: [sourceSurface])
        var step = engine.step(
            from: CGPoint(x: 100, y: 20),
            pointer: CGPoint(x: 900, y: 700),
            elapsed: 0,
            petSize: petSize,
            terrain: terrain,
            decision: decision()
        )

        step = engine.step(
            from: step.origin,
            pointer: CGPoint(x: 900, y: 700),
            elapsed: 1.1,
            petSize: petSize,
            terrain: terrain,
            decision: decision(action: 0.5, distance: 1, direction: 1)
        )
        guard case let .strolling(_, originalDestination) = step.activity else {
            return XCTFail("Expected a local stroll")
        }
        let start = step.origin

        step = engine.step(
            from: step.origin,
            pointer: CGPoint(x: -4_000, y: -4_000),
            elapsed: 0.5,
            petSize: petSize,
            terrain: terrain,
            decision: decision(action: 0, distance: 0, direction: 0)
        )

        guard case let .strolling(_, destinationAfterPointerMoved) = step.activity else {
            return XCTFail("Expected the active stroll to continue")
        }
        XCTAssertEqual(destinationAfterPointerMoved, originalDestination)
        XCTAssertEqual(step.origin.y, sourceSurface.y)
        XCTAssertGreaterThan(step.origin.x, start.x)
        XCTAssertLessThanOrEqual(originalDestination - start.x, 120)
        XCTAssertTrue(sourceSurface.span.contains(step.origin.x))
    }

    func testSustainedPointerInterestCanTriggerASafeCrossSurfaceJump() {
        var config = configuration(idle: 1)
        config.pointerInterestDuration = 0.5
        config.minimumJumpDuration = 1
        config.maximumJumpDuration = 1
        var engine = PeripheralBehaviorEngine(configuration: config)
        let terrain = TerrainSnapshot(surfaces: [sourceSurface, destinationSurface])
        let pointer = CGPoint(x: 600, y: 100)

        var step = engine.step(
            from: CGPoint(x: 100, y: sourceSurface.y),
            pointer: pointer,
            elapsed: 0,
            petSize: petSize,
            terrain: terrain,
            decision: decision()
        )
        step = engine.step(
            from: step.origin,
            pointer: pointer,
            elapsed: 1,
            petSize: petSize,
            terrain: terrain,
            decision: decision(action: 0.85, direction: 1)
        )
        XCTAssertEqual(step.renderState, .jumping)

        var sampledY: [CGFloat] = []
        for _ in 0..<10 {
            step = engine.step(
                from: step.origin,
                pointer: CGPoint(x: -1_000, y: -1_000),
                elapsed: 0.1,
                petSize: petSize,
                terrain: terrain,
                decision: decision()
            )
            sampledY.append(step.origin.y)
        }

        XCTAssertTrue(sampledY.allSatisfy { $0 >= min(sourceSurface.y, destinationSurface.y) })
        XCTAssertGreaterThan(sampledY.max() ?? 0, max(sourceSurface.y, destinationSurface.y))
        XCTAssertEqual(step.origin.y, destinationSurface.y, accuracy: 0.001)
        XCTAssertTrue(destinationSurface.span.contains(step.origin.x))
    }

    func testMissingSupportStartsRecoveryToAvailableFallback() {
        var engine = PeripheralBehaviorEngine(configuration: configuration(idle: 6))
        let originalTerrain = TerrainSnapshot(surfaces: [sourceSurface])
        let fallback = fallbackSurface
        var step = engine.step(
            from: CGPoint(x: 100, y: 20),
            pointer: .zero,
            elapsed: 0,
            petSize: petSize,
            terrain: originalTerrain,
            decision: decision()
        )

        step = engine.step(
            from: step.origin,
            pointer: .zero,
            elapsed: 0.1,
            petSize: petSize,
            terrain: TerrainSnapshot(surfaces: [fallback]),
            decision: decision()
        )

        guard case let .jumping(journey) = step.activity else {
            return XCTFail("Expected safe recovery jump")
        }
        XCTAssertEqual(journey.targetSurfaceID, fallback.id)
        XCTAssertEqual(step.renderState, .jumping)
    }

    func testAutonomousDecisionCanJumpWithoutPointerInterest() {
        var engine = PeripheralBehaviorEngine(configuration: configuration(idle: 1))
        let terrain = TerrainSnapshot(surfaces: [sourceSurface, destinationSurface])
        var step = engine.step(
            from: CGPoint(x: 100, y: sourceSurface.y),
            pointer: CGPoint(x: -1_000, y: -1_000),
            elapsed: 0,
            petSize: petSize,
            terrain: terrain,
            decision: decision()
        )

        step = engine.step(
            from: step.origin,
            pointer: CGPoint(x: -1_000, y: -1_000),
            elapsed: 1,
            petSize: petSize,
            terrain: terrain,
            decision: decision(action: 0.7, distance: 0.5)
        )

        guard case let .jumping(journey) = step.activity else {
            return XCTFail("Expected an autonomous jump")
        }
        XCTAssertEqual(journey.targetSurfaceID, destinationSurface.id)
    }

    func testFallbackTerrainProducesPeripheralRestInsteadOfCursorPursuit() {
        var engine = PeripheralBehaviorEngine(configuration: configuration(idle: 6))
        let pointer = CGPoint(x: 800, y: 700)

        let step = engine.step(
            from: CGPoint(x: 120, y: 400),
            pointer: pointer,
            elapsed: 0,
            petSize: petSize,
            terrain: TerrainSnapshot(surfaces: [fallbackSurface]),
            decision: decision()
        )

        XCTAssertEqual(step.origin.y, fallbackSurface.y)
        XCTAssertEqual(step.origin.x, 120)
        XCTAssertEqual(step.renderState, .idle)
        XCTAssertNotEqual(step.origin, pointer)
    }

    func testIdleDecisionCanUseTheExistingFlourishAnimation() {
        var engine = PeripheralBehaviorEngine(configuration: configuration(idle: 1))
        let terrain = TerrainSnapshot(surfaces: [sourceSurface])
        var step = engine.step(
            from: CGPoint(x: 100, y: 20),
            pointer: .zero,
            elapsed: 0,
            petSize: petSize,
            terrain: terrain,
            decision: decision()
        )

        step = engine.step(
            from: step.origin,
            pointer: .zero,
            elapsed: 1,
            petSize: petSize,
            terrain: terrain,
            decision: decision(action: 0.25)
        )

        XCTAssertEqual(step.renderState, .flourishing)
        guard case .flourishing = step.activity else {
            return XCTFail("Expected flourish activity")
        }
    }

    func testNapDecisionLastsLongerThanOrdinaryRest() {
        var engine = PeripheralBehaviorEngine(configuration: configuration(idle: 6))
        let terrain = TerrainSnapshot(surfaces: [sourceSurface])
        var step = engine.step(
            from: CGPoint(x: 100, y: 20),
            pointer: .zero,
            elapsed: 0,
            petSize: petSize,
            terrain: terrain,
            decision: decision()
        )

        step = engine.step(
            from: step.origin,
            pointer: .zero,
            elapsed: 6,
            petSize: petSize,
            terrain: terrain,
            decision: decision(action: 0.05, idle: 0)
        )

        guard case let .resting(_, remaining, duration) = step.activity else {
            return XCTFail("Expected a long nap")
        }
        XCTAssertGreaterThan(duration, 6)
        XCTAssertEqual(remaining, duration)
        XCTAssertEqual(step.renderState, .resting)
    }

    func testIndependentStrollIgnoresSustainedNearbyPointer() {
        var config = configuration(idle: 1)
        config.pointerInterestDuration = 0.5
        var engine = PeripheralBehaviorEngine(configuration: config)
        let terrain = TerrainSnapshot(surfaces: [sourceSurface])
        let pointer = CGPoint(x: 340, y: 100)
        var step = engine.step(
            from: CGPoint(x: 180, y: sourceSurface.y),
            pointer: pointer,
            elapsed: 0,
            petSize: petSize,
            terrain: terrain,
            decision: decision()
        )

        step = engine.step(
            from: step.origin,
            pointer: pointer,
            elapsed: 1,
            petSize: petSize,
            terrain: terrain,
            decision: decision(action: 0.5, distance: 0.5, direction: 0)
        )

        guard case let .strolling(_, destination) = step.activity else {
            return XCTFail("Expected an independent stroll")
        }
        XCTAssertLessThan(destination, step.origin.x)
        XCTAssertGreaterThan(pointer.x, step.origin.x)
    }

    func testPointerOutsideCuriosityBandDoesNotCauseCrossSurfaceJump() {
        var config = configuration(idle: 1)
        config.pointerInterestDuration = 0.5
        var engine = PeripheralBehaviorEngine(configuration: config)
        let terrain = TerrainSnapshot(surfaces: [sourceSurface, destinationSurface])
        let pointer = CGPoint(x: 600, y: 100)
        var step = engine.step(
            from: CGPoint(x: 100, y: sourceSurface.y),
            pointer: pointer,
            elapsed: 0,
            petSize: petSize,
            terrain: terrain,
            decision: decision()
        )

        step = engine.step(
            from: step.origin,
            pointer: pointer,
            elapsed: 1,
            petSize: petSize,
            terrain: terrain,
            decision: decision(action: 0.5, direction: 1)
        )

        guard case .strolling = step.activity else {
            return XCTFail("Expected the independent mood band to stroll")
        }
    }

    func testQuadraticJumpStartsAndEndsOnItsSurfaces() {
        let start = CGPoint(x: 100, y: 300)
        let end = CGPoint(x: 600, y: 200)

        XCTAssertEqual(PeripheralBehaviorEngine.jumpPoint(from: start, to: end, progress: 0, height: 90), start)
        XCTAssertEqual(PeripheralBehaviorEngine.jumpPoint(from: start, to: end, progress: 1, height: 90), end)
        XCTAssertGreaterThan(
            PeripheralBehaviorEngine.jumpPoint(from: start, to: end, progress: 0.5, height: 90).y,
            start.y
        )

        for index in 0...20 {
            let point = PeripheralBehaviorEngine.jumpPoint(
                from: start,
                to: end,
                progress: Double(index) / 20,
                height: 90
            )
            if point.x <= 450 {
                XCTAssertGreaterThanOrEqual(point.y, 300)
            }
            if point.x >= 500 {
                XCTAssertGreaterThanOrEqual(point.y, 200)
            }
        }
    }

    private func configuration(idle: TimeInterval) -> PeripheralBehaviorConfiguration {
        PeripheralBehaviorConfiguration(
            minimumIdleDuration: idle,
            maximumIdleDuration: idle,
            waitingAnimationDelay: min(2, idle / 2),
            flourishDuration: 1,
            strollSpeed: 55,
            minimumStrollDistance: 40,
            maximumStrollDistance: 120,
            pointerInterestDuration: 2,
            jumpHeight: 90,
            minimumJumpDuration: 0.8,
            maximumJumpDuration: 1.4
        )
    }

    private func decision(
        action: Double = 0.5,
        idle: Double = 0,
        distance: Double = 0.5,
        direction: Double = 0.5
    ) -> PeripheralDecisionValues {
        PeripheralDecisionValues(action: action, idleDuration: idle, distance: distance, direction: direction)
    }

    private var sourceSurface: TerrainSurface {
        TerrainSurface(
            id: "source",
            kind: .windowTop,
            sourceBounds: CGRect(x: 0, y: 0, width: 450, height: 300),
            span: 20...350,
            y: 300,
            displayBounds: CGRect(x: 0, y: 0, width: 1_000, height: 800)
        )
    }

    private var destinationSurface: TerrainSurface {
        TerrainSurface(
            id: "destination",
            kind: .windowTop,
            sourceBounds: CGRect(x: 500, y: 0, width: 450, height: 200),
            span: 520...850,
            y: 200,
            displayBounds: CGRect(x: 0, y: 0, width: 1_000, height: 800)
        )
    }

    private var fallbackSurface: TerrainSurface {
        TerrainSurface(
            id: "fallback",
            kind: .screenEdge,
            sourceBounds: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            span: 12...916,
            y: 0,
            displayBounds: CGRect(x: 0, y: 0, width: 1_000, height: 800)
        )
    }
}
