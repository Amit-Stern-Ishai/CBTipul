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

    // MARK: - Background stack
    // Navy family in dark, system palette in light.

    /// Page / screen background.
    static let base = dynamic(
        dark: 0x07080F,
        light: .systemGroupedBackground
    )

    /// Cards, sheets, side panels.
    static let surface = dynamic(
        dark: 0x0D1230,
        light: .secondarySystemGroupedBackground
    )

    /// Inputs, modals, secondary grouped areas.
    static let elevated = dynamic(
        dark: 0x131A3C,
        light: .tertiarySystemFill
    )

    /// Row hover / selected states.
    static let hover = dynamic(
        dark: 0x1A2248,
        light: .systemFill
    )

    /// Featured / highlighted cards.
    static let surfaceWarm = dynamic(
        dark: 0x1A2248,
        light: .tertiarySystemGroupedBackground
    )


    // MARK: - Borders
    // Gold-tinted in dark mode.

    static let borderFaint = dynamic(
        dark: 0xCFA038,
        darkAlpha: 0.10,
        light: .separator
    )

    static let borderDefault = dynamic(
        dark: 0xCFA038,
        darkAlpha: 0.22,
        light: .separator
    )

    static let borderStrong = dynamic(
        dark: 0xCFA038,
        darkAlpha: 0.45,
        light: .opaqueSeparator
    )


    // MARK: - Text

    /// Headings and primary body text.
    static let textBright = Color(uiColor: uiTextBright)

    /// Secondary text and captions.
    static let textBody = dynamic(
        dark: 0x8C8CA8,
        light: .secondaryLabel
    )

    /// Tertiary text, placeholder and disabled states.
    static let textFaint = Color(uiColor: uiTextFaint)


    // MARK: - Interactive accent

    /// Gold in dark mode, system blue in light.
    ///
    /// Active labels, tinted icons and links.
    static let gold = dynamic(
        dark: 0xCFA038,
        light: .systemBlue
    )

    /// Hover / focus state on accent elements.
    static let goldVivid = dynamic(
        dark: 0xF2C050,
        light: .systemBlue
    )

    /// Pressed state of accent elements.
    static let goldDim = dynamic(
        dark: 0x7A5C1A,
        light: .systemBlue
    )

    /// Soft accent fills: secondary buttons, pills and highlighted icon chips.
    static let goldGhost = dynamic(
        dark: 0xCFA038,
        darkAlpha: 0.12,
        light: .systemBlue.withAlphaComponent(0.12)
    )

    /// Solid brand fills: primary buttons, avatars and selected fills.
    static let accentFill = dynamic(
        dark: 0xCFA038,
        light: .systemBlue
    )

    /// Pressed state of `accentFill`.
    static let accentFillPressed = dynamic(
        dark: 0x7A5C1A,
        light: .systemBlue
    )

    /// Text and icons sitting on `accentFill`.
    static let textOnAccent = dynamic(
        dark: 0x07080F,
        light: .white
    )


    // MARK: - Prestige

    /// Warm gold used sparingly for emphasis and AI-insight markers.
    static let prestige = dynamic(
        dark: 0xCFA038,
        light: .systemBlue
    )

    static let prestigeGhost = dynamic(
        dark: 0xCFA038,
        darkAlpha: 0.12,
        light: .systemBlue.withAlphaComponent(0.12)
    )


    // MARK: - Brand
    // Dark mode keeps the navy / gold identity.

    /// Primary actions and strong brand elements.
    /// Never use for destructive actions.
    static let brandPrimary = accentFill

    /// Pressed / secondary brand states.
    static let brandSecondary = dynamic(
        dark: 0xF2C050,
        light: .systemBlue
    )

    /// Main interactive accent.
    static let brandAccent = gold

    /// Subtle highlighted backgrounds and secondary buttons.
    static let brandAccentSoft = dynamic(
        dark: 0x1A2248,
        light: .systemFill
    )

    /// Sparing emphasis.
    static let brandHighlight = prestige

    /// Soft brand tint for selected / branded fills.
    static let brandSoft = dynamic(
        dark: 0x1A2248,
        light: .systemFill
    )


    // MARK: - Semantic
    //
    // Dark-mode semantic colors are intentionally brighter than the
    // surrounding navy/gold palette. They need to communicate meaning
    // immediately without looking muddy against dark surfaces.
    //
    // Strong variants:
    //     icons, labels, values, arrows
    //
    // Soft variants:
    //     card fills, badges, pills, highlighted rows
    //
    // Never communicate semantic meaning through color alone.

    // MARK: Success / Green

    /// General success.
    static let success = dynamic(
        dark: 0x42D98B,
        light: .systemGreen
    )


    // MARK: Warning / Yellow

    /// Attention required, but not necessarily negative.
    static let warning = dynamic(
        dark: 0xFFC94A,
        light: .systemOrange
    )

    static let warningSoft = dynamic(
        dark: 0xFFC94A,
        darkAlpha: 0.14,
        light: .systemOrange.withAlphaComponent(0.12)
    )


    // MARK: Error / Red

    /// Errors, destructive states and negative meaning.
    static let error = dynamic(
        dark: 0xFF5C68,
        light: .systemRed
    )


    // MARK: - Clinical semantics

    // IMPORTANT:
    //
    // Color follows the CLINICAL MEANING of a change, not simply whether
    // the raw number went up or down.
    //
    // For symptom questionnaires such as GAD-7 / PHQ-9:
    //
    //     14 → 8   = positive / green
    //      8 → 14  = negative / red
    //      8 → 8   = neutral / gray
    //
    // Pair these colors with arrows, icons or text labels.

    // MARK: Positive / Improvement

    /// Improvement, symptom reduction or favorable change.
    static let positive = success

    /// Strong green for prominent values / chart points.
    static let positiveMedium = dynamic(
        dark: 0x42D98B,
        light: .systemGreen
    )

    /// Subtle green fill behind positive content.
    static let positiveSoft = dynamic(
        dark: 0x42D98B,
        darkAlpha: 0.14,
        light: .systemGreen.withAlphaComponent(0.12)
    )


    // MARK: Negative / Worsening

    /// Worsening, symptom increase or clinically important deterioration.
    ///
    /// Reserved for actual negative meaning — never use red simply because
    /// something is important.
    static let negative = error

    /// Strong red for prominent values / chart points.
    static let negativeMedium = dynamic(
        dark: 0xFF5C68,
        light: .systemRed
    )

    /// Subtle red fill behind negative content.
    static let negativeSoft = dynamic(
        dark: 0xFF5C68,
        darkAlpha: 0.14,
        light: .systemRed.withAlphaComponent(0.12)
    )


    // MARK: Neutral / No meaningful change

    /// No meaningful change, unavailable comparison or plain information.
    static let neutral = dynamic(
        dark: 0xA7A7BE,
        light: .systemGray
    )

    static let neutralMedium = dynamic(
        dark: 0x77778F,
        light: .systemGray2
    )

    static let neutralSoft = dynamic(
        dark: 0xA7A7BE,
        darkAlpha: 0.10,
        light: .tertiarySystemFill
    )


    // MARK: Critical clinical alert

    /// Critical clinical alerts, such as PHQ-9 question 9.
    ///
    /// Intentionally brighter and stronger than an ordinary error.
    /// Reserve this token for genuinely important clinical situations.
    static let critical = dynamic(
        dark: 0xFF4055,
        light: .systemRed
    )

    static let criticalSoft = dynamic(
        dark: 0xFF4055,
        darkAlpha: 0.20,
        light: .systemRed.withAlphaComponent(0.18)
    )


    // MARK: - UIKit-facing dynamic colors

    // Wrapped UIKit views can lose palette dynamism through a
    // UIColor(Color) bridge, so UIKit-facing colors are provided directly.

    static let uiTextBright = dynamicUIColor(
        dark: 0xF2EDE0,
        light: .label
    )

    static let uiTextFaint = dynamicUIColor(
        dark: 0x3A3A54,
        light: .placeholderText
    )

    static let uiAccentFill = dynamicUIColor(
        dark: 0xCFA038,
        light: .systemBlue
    )

    static let uiTextOnAccent = dynamicUIColor(
        dark: 0x07080F,
        light: .white
    )

    static let uiElevated = dynamicUIColor(
        dark: 0x131A3C,
        light: .tertiarySystemFill
    )


    // MARK: - Appearance resolution

    /// The palette currently selected in Settings.
    ///
    /// Read inside the dynamic providers so a palette change re-resolves
    /// every color: switching appearance always flips the color scheme, and
    /// that trait change re-runs every dynamic provider.
    private static var storedAppearance: AppAppearance {
        UserDefaults.standard
            .string(forKey: "appAppearance")
            .flatMap(AppAppearance.init(rawValue:)) ?? .dark
    }

    private static func dynamic(
        dark: UInt32,
        darkAlpha: CGFloat = 1,
        light: UIColor
    ) -> Color {
        Color(
            uiColor: UIColor { traits in
                if storedAppearance == .light {
                    return light.resolvedColor(with: traits)
                }

                return UIColor(hex: dark)
                    .withAlphaComponent(darkAlpha)
            }
        )
    }

    private static func dynamicUIColor(
        dark: UInt32,
        light: UIColor
    ) -> UIColor {
        UIColor { traits in
            if storedAppearance == .light {
                return light.resolvedColor(with: traits)
            }

            return UIColor(hex: dark)
        }
    }
}


// MARK: - UIColor + Hex

extension UIColor {

    /// Creates a color from a 0xRRGGBB literal.
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}


// MARK: - Theme View Modifiers

extension View {

    /// Lays a scrolling screen (List/Form/ScrollView) on the Theme.base
    /// background instead of the system background.
    func themedScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.base.ignoresSafeArea())
    }

    /// Standard card chrome:
    /// Theme.surface background with a faint border.
    func themedCard(cornerRadius: CGFloat = 16) -> some View {
        background(
            Theme.surface,
            in: RoundedRectangle(cornerRadius: cornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Theme.borderFaint)
        )
    }
}
