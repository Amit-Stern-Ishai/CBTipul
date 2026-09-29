import SwiftUI

/// A row's place inside its list section, deciding which parts of the thin
/// group outline it draws.
enum GroupRowPosition {
    case only, first, middle, last

    /// The position of the row at `index` in a group of `count` rows.
    static func at(_ index: Int, of count: Int) -> GroupRowPosition {
        if count <= 1 { return .only }
        if index == 0 { return .first }
        return index == count - 1 ? .last : .middle
    }
}

/// Corner radius of the group outline, matching the inset-grouped
/// section corners.
private let groupCornerRadius: CGFloat = 26

/// Shared row surface. SwiftUI supplies the section's outer shape;
/// patient identity colors stay on avatars and action icons.
@MainActor
func groupBorderedRow(_ position: GroupRowPosition, accent: Color) -> some View {
    // SwiftUI clips the entire section. Per-row rounded outlines create
    // doubled corners, so let the native section shape define the edge.
    Theme.surface
}

/// One row's share of a section group's outline: the two side lines, plus
/// the rounded top/bottom cap on the group's outer rows. Adjacent rows'
/// side lines meet at the row boundaries, so together they read as one
/// continuous border around the group.
struct GroupBorderEdge: Shape {
    let position: GroupRowPosition
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        // Side lines sit half a point inside so a 1 pt stroke isn't clipped;
        // shared row edges stay exact so the lines connect without gaps.
        let minX = rect.minX + 0.5
        let maxX = rect.maxX - 0.5
        let minY = position == .first || position == .only ? rect.minY + 0.5 : rect.minY
        let maxY = position == .last || position == .only ? rect.maxY - 0.5 : rect.maxY

        var path = Path()
        switch position {
        case .only:
            path.addRoundedRect(
                in: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY),
                cornerSize: CGSize(width: radius, height: radius)
            )
        case .first:
            path.move(to: CGPoint(x: minX, y: maxY))
            path.addLine(to: CGPoint(x: minX, y: minY + radius))
            path.addArc(tangent1End: CGPoint(x: minX, y: minY),
                        tangent2End: CGPoint(x: minX + radius, y: minY),
                        radius: radius)
            path.addLine(to: CGPoint(x: maxX - radius, y: minY))
            path.addArc(tangent1End: CGPoint(x: maxX, y: minY),
                        tangent2End: CGPoint(x: maxX, y: minY + radius),
                        radius: radius)
            path.addLine(to: CGPoint(x: maxX, y: maxY))
        case .middle:
            path.move(to: CGPoint(x: minX, y: minY))
            path.addLine(to: CGPoint(x: minX, y: maxY))
            path.move(to: CGPoint(x: maxX, y: minY))
            path.addLine(to: CGPoint(x: maxX, y: maxY))
        case .last:
            path.move(to: CGPoint(x: minX, y: minY))
            path.addLine(to: CGPoint(x: minX, y: maxY - radius))
            path.addArc(tangent1End: CGPoint(x: minX, y: maxY),
                        tangent2End: CGPoint(x: minX + radius, y: maxY),
                        radius: radius)
            path.addLine(to: CGPoint(x: maxX - radius, y: maxY))
            path.addArc(tangent1End: CGPoint(x: maxX, y: maxY),
                        tangent2End: CGPoint(x: maxX, y: maxY - radius),
                        radius: radius)
            path.addLine(to: CGPoint(x: maxX, y: minY))
        }
        return path
    }
}
