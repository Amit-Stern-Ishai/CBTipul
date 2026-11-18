import SwiftUI
import UIKit

/// Rubik from the supplied brand guide, bundled under the SIL Open Font License.
/// Relative text styles preserve Dynamic Type, including accessibility sizes.
enum BrandTypography {
    static let largeTitle = Font.custom("Rubik-Light_Regular", size: 34, relativeTo: .largeTitle)
    static let title = Font.custom("Rubik-Light_Regular", size: 28, relativeTo: .title)
    static let title2 = Font.custom("Rubik-Light_Regular", size: 22, relativeTo: .title2)
    static let title3 = Font.custom("Rubik-Light_Regular", size: 20, relativeTo: .title3)
    static let headline = Font.custom("Rubik-Light_Regular", size: 17, relativeTo: .headline).weight(.semibold)
    static let subheadline = Font.custom("Rubik-Light_Regular", size: 15, relativeTo: .subheadline)
    static let body = Font.custom("Rubik-Light_Regular", size: 17, relativeTo: .body)
    static let callout = Font.custom("Rubik-Light_Regular", size: 16, relativeTo: .callout)
    static let footnote = Font.custom("Rubik-Light_Regular", size: 13, relativeTo: .footnote)
    static let caption = Font.custom("Rubik-Light_Regular", size: 12, relativeTo: .caption)
    static let caption2 = Font.custom("Rubik-Light_Regular", size: 11, relativeTo: .caption2)

    static func editorFont(compatibleWith traits: UITraitCollection) -> UIFont {
        let base = UIFont(name: "Rubik-Light_Regular", size: 17) ?? UIFont.systemFont(ofSize: 17)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: base, compatibleWith: traits)
    }
}

// An explicit principal label keeps SwiftUI navigation chrome in the bundled
// typeface; UIKit appearance attributes alone are overridden by some sheets.
extension View {
    func brandNavigationTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(BrandTypography.headline)
                        .foregroundStyle(Theme.textBright)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}
