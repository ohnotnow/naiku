import AppKit
import CoreGraphics

@MainActor
final class CoreGraphicsWindowTerrainProvider: WindowTerrainProviding {
    private let ownPID: pid_t

    init(ownPID: pid_t = ProcessInfo.processInfo.processIdentifier) {
        self.ownPID = ownPID
    }

    func snapshot(petSize: CGSize) -> TerrainSnapshot {
        WindowTerrainBuilder.build(
            records: Self.currentRecords(),
            displays: DesktopGeometry.currentDisplays,
            primaryDisplayMaxY: NSScreen.screens.first?.frame.maxY ?? 0,
            petSize: petSize,
            ownPID: ownPID
        )
    }

    func hasFullScreenWindow(near petFrame: CGRect) -> Bool {
        FullScreenSpaceDetector.hasFullScreenWindow(
            records: Self.currentRecords(),
            displays: DesktopGeometry.currentDisplays,
            primaryDisplayMaxY: NSScreen.screens.first?.frame.maxY ?? 0,
            near: petFrame,
            ownPID: ownPID
        )
    }

    private static func currentRecords() -> [WindowGeometryRecord] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let dictionaries = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return dictionaries.compactMap(Self.record(from:))
    }

    private static func record(from dictionary: [String: Any]) -> WindowGeometryRecord? {
        guard
            let number = dictionary[kCGWindowNumber as String] as? NSNumber,
            let boundsDictionary = dictionary[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
            let layer = dictionary[kCGWindowLayer as String] as? NSNumber,
            let alpha = dictionary[kCGWindowAlpha as String] as? NSNumber,
            let ownerPID = dictionary[kCGWindowOwnerPID as String] as? NSNumber
        else {
            return nil
        }

        return WindowGeometryRecord(
            id: number.uint32Value,
            quartzBounds: bounds,
            layer: layer.intValue,
            alpha: CGFloat(alpha.doubleValue),
            ownerPID: ownerPID.int32Value
        )
    }
}
