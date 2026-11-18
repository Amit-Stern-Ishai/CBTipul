import Testing
import SwiftUI
import UIKit
@testable import CBTipul

@MainActor struct BrandGuideTests {
    @Test func bundledRubikSupportsHebrewAndDynamicType() throws {
        let font = try #require(UIFont(name: "Rubik-Light_Regular", size: 17))
        #expect(font.familyName.contains("Rubik"))
        let normal = BrandTypography.editorFont(compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        let large = BrandTypography.editorFont(compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
        #expect(large.pointSize > normal.pointSize)
        var characters: [UniChar] = [0x05D0, 0x05EA]
        var glyphs: [CGGlyph] = [0, 0]
        #expect(CTFontGetGlyphsForCharacters(font as CTFont, &characters, &glyphs, 2))
    }

    @Test func textAndActionContrastInBothAppearances() {
        let old = UserDefaults.standard.object(forKey: "appAppearance")
        defer { if let old { UserDefaults.standard.set(old, forKey: "appAppearance") } else { UserDefaults.standard.removeObject(forKey: "appAppearance") } }
        for mode in ["light", "dark"] {
            UserDefaults.standard.set(mode, forKey: "appAppearance")
            let traits = UITraitCollection(userInterfaceStyle: mode == "light" ? .light : .dark)
            for (ink, fill) in [(Theme.textBright, Theme.base), (Theme.textBody, Theme.surface), (Theme.textFaint, Theme.elevated), (Theme.textOnAccent, Theme.accentFill), (Theme.headerInk, Theme.patientHomeHeader)] {
                #expect(contrast(ink, fill, traits) >= 4.5)
            }
            for fill in [Theme.severityMinimal, Theme.severityMild, Theme.severityModerate, Theme.severitySevere, Theme.turquoise] {
                #expect(contrast(Theme.turquoiseInk, fill, traits) >= 4.5)
            }
        }
    }
    private func contrast(_ a: Color, _ b: Color, _ traits: UITraitCollection) -> Double {
        func luminance(_ color: Color) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
            UIColor(color).resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &alpha)
            func linear(_ c: CGFloat) -> Double { let x = Double(c); return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
            return linear(r) * 0.2126 + linear(g) * 0.7152 + linear(b) * 0.0722
        }
        let x = luminance(a), y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
