import SwiftUI

/// The app's design system, resolved per the appearance setting:
///
/// - **Dark** (default): Navy-Midnight surfaces with a single gold accent.
/// - **Light**: the native iOS palette (system backgrounds, labels and the
///   standard blue tint) rendered in light appearance.
///
/// Semantic colors are used full-opacity for icons/text with soft tints for
/// fills, never through color alone.
enum Theme {
    // MARK: Background stack (navy family in dark, system palette in light)
    /// Page / screen background.
    static let base = dynamic(dark: 0x07080F, light: .systemGroupedBackground)
    /// Cards, sheets, side panels.
    static let surface = dynamic(dark: 0x0D1230, light: .secondarySystemGroupedBackground)
    /// Inputs, modals, secondary grouped areas.
    static let elevated = dynamic(dark: 0x131A3C, light: .tertiarySystemFill)
    /// Row hover / selected states.
    static let hover = dynamic(dark: 0x1A2248, light: .systemFill)
    /// Featured / highlighted cards.
    static let surfaceWarm = dynamic(dark: 0x1A2248, light: .tertiarySystemGroupedBackground)

    // MARK: Borders (gold-tinted in dark)
    static let borderFaint = dynamic(dark: 0xCFA038, darkAlpha: 0.10, light: .separator)
    static let borderDefault = dynamic(dark: 0xCFA038, darkAlpha: 0.22, light: .separator)
    static let borderStrong = dynamic(dark: 0xCFA038, darkAlpha: 0.45, light: .opaqueSeparator)

    // MARK: Text
    /// Headings, primary body.
    static let textBright = Color(uiColor: uiTextBright)
    /// Secondary text, captions.
    static let textBody = dynamic(dark: 0x8C8CA8, light: .secondaryLabel)
    /// Tertiary text, placeholder, disabled.
    static let textFaint = Color(uiColor: uiTextFaint)

    // MARK: Interactive accent
    // Gold in dark mode, system blue in light.
    /// Active labels, tinted icons, links — the text-weight accent.
    static let gold = dynamic(dark: 0xCFA038, light: .systemBlue)
    /// Hover / focus state on accent elements (e.g. focused field borders).
    static let goldVivid = dynamic(dark: 0xF2C050, light: .systemBlue)
    /// Pressed state of accent elements.
    static let goldDim = dynamic(dark: 0x7A5C1A, light: .systemBlue)
    /// Soft accent fills: secondary buttons, pills, highlighted icon chips.
    static let goldGhost = dynamic(dark: 0xCFA038, darkAlpha: 0.12,
                                   light: .systemBlue.withAlphaComponent(0.12))
    /// Solid brand fills: primary buttons, avatars, selected fills.
    static let accentFill = dynamic(dark: 0xCFA038, light: .systemBlue)
    /// Pressed state of `accentFill`.
    static let accentFillPressed = dynamic(dark: 0x7A5C1A, light: .systemBlue)
    /// Text and icons sitting on `accentFill`.
    static let textOnAccent = dynamic(dark: 0x07080F, light: .white)

    // MARK: Prestige (Warm Gold — sparing emphasis, AI-insight markers)
    static let prestige = dynamic(dark: 0xCFA038, light: .systemBlue)
    static let prestigeGhost = dynamic(dark: 0xCFA038, darkAlpha: 0.12,
                                       light: .systemBlue.withAlphaComponent(0.12))

    // MARK: Brand (dark keeps the navy/gold identity)
    /// Primary actions and strong brand elements (same token as
    /// `accentFill`). Never used for destructive actions.
    static let brandPrimary = accentFill
    /// Pressed/secondary brand states.
    static let brandSecondary = dynamic(dark: 0xF2C050, light: .systemBlue)
    /// The balancing interactive accent (same token as `gold`).
    static let brandAccent = gold
    /// Subtle highlighted backgrounds and secondary buttons.
    static let brandAccentSoft = dynamic(dark: 0x1A2248, light: .systemFill)
    /// Sparing emphasis (same token as `prestige`).
    static let brandHighlight = prestige
    /// Soft brand tint for selected/branded fills.
    static let brandSoft = dynamic(dark: 0x1A2248, light: .systemFill)

    // MARK: Semantic (text/icons full opacity, soft tints for fills)
    static let success = dynamic(dark: 0x3D7C5A, light: .systemGreen)
    static let warning = dynamic(dark: 0xB87820, light: .systemOrange)
    static let warningSoft = dynamic(dark: 0xB87820, darkAlpha: 0.15,
                                     light: .systemOrange.withAlphaComponent(0.12))
    static let error = dynamic(dark: 0x7C2838, light: .systemRed)

    // MARK: Clinical semantics
    // Color follows the clinical meaning of a change — improvement,
    // worsening, or no meaningful change — never the raw direction of a
    // number (GAD-7 14 → 8 is positive). Soft variants back cards; the
    // strong value carries the icon/text on top of them.
    /// Improvement, symptom reduction, favorable change (same as `success`).
    static let positive = success
    static let positiveMedium = dynamic(dark: 0x2EAF71, light: .systemGreen)
    static let positiveSoft = dynamic(dark: 0x3D7C5A, darkAlpha: 0.15,
                                      light: .systemGreen.withAlphaComponent(0.12))
    /// Worsening, symptom increase, clinically important deterioration
    /// (same token as `error`). Reserved for negative meaning — never used
    /// just because an action is important.
    static let negative = error
    static let negativeMedium = dynamic(dark: 0xE74C3C, light: .systemRed)
    static let negativeSoft = dynamic(dark: 0x7C2838, darkAlpha: 0.18,
                                      light: .systemRed.withAlphaComponent(0.12))
    /// No meaningful change, unavailable comparison, plain information.
    static let neutral = dynamic(dark: 0x8C8CA8, light: .systemGray)
    static let neutralMedium = dynamic(dark: 0x5A5A74, light: .systemGray2)
    static let neutralSoft = dynamic(dark: 0x131A3C, light: .tertiarySystemFill)
    /// Critical clinical alerts (e.g. PHQ-9 question 9) — visually stronger
    /// than an ordinary validation error and reserved for genuinely
    /// important clinical situations.
    static let critical = dynamic(dark: 0xD9556A, light: .systemRed)
    static let criticalSoft = dynamic(dark: 0x9D2635, darkAlpha: 0.25,
                                      light: .systemRed.withAlphaComponent(0.18))

    // MARK: UIKit-facing dynamic colors (for wrapped UIKit views, which
    // would lose the palette dynamism through a `UIColor(Color)` bridge).
    static let uiTextBright = dynamicUIColor(dark: 0xF2EDE0, light: .label)
    static let uiTextFaint = dynamicUIColor(dark: 0x3A3A54, light: .placeholderText)
    static let uiAccentFill = dynamicUIColor(dark: 0xCFA038, light: .systemBlue)
    static let uiTextOnAccent = dynamicUIColor(dark: 0x07080F, light: .white)
    static let uiElevated = dynamicUIColor(dark: 0x131A3C, light: .tertiarySystemFill)

    /// The palette currently selected in Settings. Read inside the dynamic
    /// providers so a palette change re-resolves every color (the root
    /// modifier re-identifies the view tree when it changes).
    private static var storedAppearance: AppAppearance {
        UserDefaults.standard.string(forKey: "appAppearance")
            .flatMap(AppAppearance.init(rawValue:)) ?? .dark
    }

    private static func dynamic(dark: UInt32, darkAlpha: CGFloat = 1,
                                light: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            if storedAppearance == .light {
                return light.resolvedColor(with: traits)
            }
            return UIColor(hex: dark).withAlphaComponent(darkAlpha)
        })
    }

    private static func dynamicUIColor(dark: UInt32, light: UIColor) -> UIColor {
        UIColor { traits in
            if storedAppearance == .light {
                return light.resolvedColor(with: traits)
            }
            return UIColor(hex: dark)
        }
    }
}

extension UIColor {
    /// A color from a 0xRRGGBB literal.
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension View {
    /// Lays a scrolling screen (List/Form/ScrollView) on the Base background
    /// instead of the system one.
    func themedScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.base.ignoresSafeArea())
    }

    /// Card chrome: Surface background with a Faint border.
    func themedCard(cornerRadius: CGFloat = 16) -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Theme.borderFaint)
            )
    }
}
