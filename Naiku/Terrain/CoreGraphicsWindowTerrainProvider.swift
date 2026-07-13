import AppKit
import CoreGraphics

@MainActor
final class CoreGraphicsWindowTerrainProvider: WindowTerrainProviding {
    private let ownPID: pid_t

    init(ownPID: pid_t = ProcessInfo.processInfo.processIdentifier) {
        self.ownPID = ownPID
    }

    func snapshot(petSize: CGSize) -> TerrainSnapshot {
        let displays = DesktopGeometry.currentDisplays
        let primaryDisplayMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let dictionaries = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []

        let records = dictionaries.compactMap(Self.record(from:))
        return WindowTerrainBuilder.build(
            records: records,
            displays: displays,
            primaryDisplayMaxY: primaryDisplayMaxY,
            petSize: petSize,
            ownPID: ownPID
        )
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
