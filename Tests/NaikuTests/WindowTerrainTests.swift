import CoreGraphics
import XCTest
@testable import Naiku

final class WindowTerrainTests: XCTestCase {
    private let petSize = CGSize(width: 72, height: 72)

    func testQuartzCoordinatesConvertAcrossPrimaryAndStackedDisplays() {
        XCTAssertEqual(
            WindowTerrainBuilder.appKitRect(
                fromQuartz: CGRect(x: 40, y: 100, width: 300, height: 400),
                primaryDisplayMaxY: 1_440
            ),
            CGRect(x: 40, y: 940, width: 300, height: 400)
        )

        XCTAssertEqual(
            WindowTerrainBuilder.appKitRect(
                fromQuartz: CGRect(x: 300, y: -600, width: 800, height: 500),
                primaryDisplayMaxY: 1_440
            ),
            CGRect(x: 300, y: 1_540, width: 800, height: 500)
        )
    }

    func testFilteringLeavesOnlyUsableWindowTopsAndFallback() {
        let display = DisplayGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            visibleFrame: CGRect(x: 0, y: 24, width: 1_000, height: 746)
        )
        let records = [
            record(id: 1, rect: CGRect(x: 100, y: 200, width: 600, height: 300)),
            record(id: 2, rect: CGRect(x: 100, y: 200, width: 600, height: 300), ownerPID: 42),
            record(id: 3, rect: CGRect(x: 100, y: 200, width: 600, height: 300), layer: 2),
            record(id: 4, rect: CGRect(x: 100, y: 200, width: 600, height: 300), alpha: 0),
            record(id: 5, rect: CGRect(x: 100, y: 200, width: 120, height: 60)),
            record(id: 6, rect: CGRect(x: 1_500, y: 200, width: 600, height: 300)),
            record(id: 7, rect: CGRect(x: 100, y: 40, width: 600, height: 40)),
        ]

        let snapshot = WindowTerrainBuilder.build(
            records: records,
            displays: [display],
            primaryDisplayMaxY: 800,
            petSize: petSize,
            ownPID: 42
        )

        XCTAssertEqual(snapshot.windowSurfaces.map(\.id), ["window-1-0"])
        XCTAssertEqual(snapshot.fallbackSurfaces.map(\.id), ["screen-edge-0"])
        XCTAssertEqual(snapshot.windowSurfaces[0].span, 112...616)
        XCTAssertEqual(snapshot.windowSurfaces[0].y, 600)
    }

    func testFrontWindowCutsAHiddenSectionFromBackWindowTop() {
        let display = DisplayGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
        )
        let frontOccluder = record(id: 10, rect: CGRect(x: 300, y: 100, width: 300, height: 150))
        let backWindow = record(id: 11, rect: CGRect(x: 100, y: 200, width: 800, height: 500))

        let snapshot = WindowTerrainBuilder.build(
            records: [frontOccluder, backWindow],
            displays: [display],
            primaryDisplayMaxY: 800,
            petSize: petSize,
            ownPID: 99
        )
        let backSpans = snapshot.windowSurfaces
            .filter { $0.id.hasPrefix("window-11-") }
            .map(\.span)

        XCTAssertEqual(backSpans, [112...216, 612...816])
        XCTAssertFalse(backSpans.contains { $0.contains(400) })
    }

    func testEveryDisplayGetsAScreenEdgeFallback() {
        let displays = [
            DisplayGeometry(
                frame: CGRect(x: -1_200, y: -200, width: 1_200, height: 900),
                visibleFrame: CGRect(x: -1_200, y: -176, width: 1_200, height: 876)
            ),
            DisplayGeometry(
                frame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
                visibleFrame: CGRect(x: 0, y: 24, width: 1_440, height: 852)
            ),
        ]

        let snapshot = WindowTerrainBuilder.build(
            records: [],
            displays: displays,
            primaryDisplayMaxY: 900,
            petSize: petSize,
            ownPID: 99
        )

        XCTAssertEqual(snapshot.surfaces.count, 2)
        XCTAssertTrue(snapshot.surfaces.allSatisfy { $0.kind == .screenEdge })
        XCTAssertEqual(snapshot.surfaces[0].y, -176)
        XCTAssertEqual(snapshot.surfaces[1].y, 24)
    }

    func testNearTopWindowMayUseOnlyTheTitleBarBand() {
        let display = DisplayGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 770)
        )
        let nearTop = record(id: 20, rect: CGRect(x: 100, y: 70, width: 700, height: 660))
        let maximised = record(id: 21, rect: CGRect(x: 100, y: 0, width: 700, height: 800))

        let snapshot = WindowTerrainBuilder.build(
            records: [nearTop, maximised],
            displays: [display],
            primaryDisplayMaxY: 800,
            petSize: petSize,
            ownPID: 99
        )

        let nearTopSurface = snapshot.windowSurfaces.first { $0.id == "window-20-0" }
        XCTAssertEqual(nearTopSurface?.y, 698)
        XCTAssertNil(snapshot.windowSurfaces.first { $0.id.hasPrefix("window-21-") })
    }

    @MainActor
    func testControllerRefreshesTerrainSeparatelyFromMotion() {
        let stub = TerrainProviderStub()
        let controller = PetWindowController(screen: nil, terrainProvider: stub)

        controller.refreshTerrain()

        XCTAssertEqual(stub.snapshotCount, 1)
        XCTAssertEqual(controller.terrainSnapshot, stub.result)
        XCTAssertEqual(PetWindowController.terrainRefreshInterval, 1.0)
        XCTAssertGreaterThan(PetWindowController.terrainRefreshInterval, PetWindowController.frameInterval)
        controller.tearDown()
    }

    private func record(
        id: UInt32,
        rect: CGRect,
        ownerPID: pid_t = 7,
        layer: Int = 0,
        alpha: CGFloat = 1
    ) -> WindowGeometryRecord {
        WindowGeometryRecord(id: id, quartzBounds: rect, layer: layer, alpha: alpha, ownerPID: ownerPID)
    }
}

@MainActor
private final class TerrainProviderStub: WindowTerrainProviding {
    private(set) var snapshotCount = 0
    let result = TerrainSnapshot(surfaces: [
        TerrainSurface(
            id: "stub",
            kind: .screenEdge,
            sourceBounds: CGRect(x: 0, y: 0, width: 500, height: 400),
            span: 12...416,
            y: 0,
            displayBounds: CGRect(x: 0, y: 0, width: 500, height: 400)
        ),
    ])

    func snapshot(petSize: CGSize) -> TerrainSnapshot {
        snapshotCount += 1
        return result
    }
}
