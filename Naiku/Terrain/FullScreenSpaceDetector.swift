import CoreGraphics
import Foundation

/// Decides whether the active Space is showing a full-screen window on the
/// display Naiku currently inhabits.
///
/// Withholding `.fullScreenAuxiliary` is not enough to keep a
/// `.canJoinAllSpaces` floating panel out of full-screen Spaces, so the pet
/// has to notice covering windows and step aside itself.
enum FullScreenSpaceDetector {
    /// Full-screen content on a notched display sits just below the camera
    /// housing, so a full-screen window's top edge may fall a little short
    /// of the display frame.
    static let topInsetTolerance: CGFloat = 40

    static func hasFullScreenWindow(
        records: [WindowGeometryRecord],
        displays: [DisplayGeometry],
        primaryDisplayMaxY: CGFloat,
        near petFrame: CGRect,
        ownPID: pid_t
    ) -> Bool {
        guard !displays.isEmpty else { return false }

        let petCenter = CGPoint(x: petFrame.midX, y: petFrame.midY)
        let candidates: [DisplayGeometry] =
            displays.first(where: { $0.frame.contains(petCenter) }).map { [$0] } ?? displays

        for record in records {
            guard record.ownerPID != ownPID, record.layer == 0, record.alpha > 0 else { continue }

            let rect = WindowTerrainBuilder.appKitRect(
                fromQuartz: record.quartzBounds,
                primaryDisplayMaxY: primaryDisplayMaxY
            )
            if candidates.contains(where: { covers(display: $0.frame, rect: rect) }) {
                return true
            }
        }
        return false
    }

    private static func covers(display: CGRect, rect: CGRect) -> Bool {
        rect.minX <= display.minX + 1
            && rect.maxX >= display.maxX - 1
            && rect.minY <= display.minY + 1
            && rect.maxY >= display.maxY - topInsetTolerance
    }
}
