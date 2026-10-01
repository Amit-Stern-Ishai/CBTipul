import SwiftUI

/// The app's design system, resolved per the appearance setting:
///
/// - **Dark** (default): Navy-Midnight surfaces with a single gold accent.
/// - **Light**: crisp white surfaces, navy actions and blue accents.
///
/// Semantic colors are used full-opacity for icons/text with soft tints for
/// fills, never through color alone.
enum Theme {

    // MARK: - Background stack
    // Navy family in dark, cool neutral surfaces in light.

    /// Page / screen background.
    static let base = dynamic(
        dark: 0x0C1420,
        light: UIColor(hex: 0xF1F4F8)
    )

    /// Cards, sheets, side panels.
    static let surface = dynamic(
        dark: 0x172231,
        light: UIColor(hex: 0xFFFFFF)
    )

    /// Inputs, modals, secondary grouped areas.
    static let elevated = dynamic(
        dark: 0x202E40,
        light: UIColor(hex: 0xE8EEF5)
    )

    /// Row hover / selected states.
    static let hover = dynamic(
        dark: 0x29394D,
        light: UIColor(hex: 0xDCE6F1)
    )

    /// Featured / highlighted cards.
    static let surfaceWarm = dynamic(
        dark: 0x29394D,
        light: UIColor(hex: 0xEBF2FA)
    )


    // MARK: - Borders
    // Neutral outlines keep the accent reserved for actions and selection.

    static let borderFaint = dynamic(
        dark: 0x2C394B,
        light: UIColor(hex: 0xDFE5ED)
    )

    static let borderDefault = dynamic(
        dark: 0x3B4B60,
        light: UIColor(hex: 0xCAD5E2)
    )

    static let borderStrong = dynamic(
        dark: 0x60738C,
        light: UIColor(hex: 0x94A5BB)
    )


    // MARK: - Text

    /// Headings and primary body text.
    static let textBright = Color(uiColor: uiTextBright)

    /// Secondary text and captions.
    static let textBody = dynamic(
        dark: 0xB4C0D0,
        light: UIColor(hex: 0x4B5E75)
    )

    /// Tertiary text, placeholder and disabled states.
    static let textFaint = Color(uiColor: uiTextFaint)


    // MARK: - Interactive accent

    /// Warm gold in dark mode, clear blue for light-mode links.
    ///
    /// Active labels, tinted icons and links.
    static let gold = dynamic(
        dark: 0xE2BB76,
        light: UIColor(hex: 0x285A8C)
    )

    /// Hover / focus state on accent elements.
    static let goldVivid = dynamic(
        dark: 0xF1D29A,
        light: UIColor(hex: 0x356DAB)
    )

    /// Pressed state of accent elements.
    static let goldDim = dynamic(
        dark: 0xC49C58,
        light: UIColor(hex: 0x1B446E)
    )

    /// Soft accent fills: secondary buttons, pills and highlighted icon chips.
    static let goldGhost = dynamic(
        dark: 0xE2BB76,
        darkAlpha: 0.12,
        light: UIColor(hex: 0x285A8C).withAlphaComponent(0.10)
    )

    /// Solid brand fills: primary buttons, avatars and selected fills.
    static let accentFill = dynamic(
        dark: 0xE2BB76,
        light: UIColor(hex: 0x203E61)
    )

    /// Pressed state of `accentFill`.
    static let accentFillPressed = dynamic(
        dark: 0xC49C58,
        light: UIColor(hex: 0x172F4C)
    )

    /// Text and icons sitting on `accentFill`.
    static let textOnAccent = dynamic(
        dark: 0x0C1420,
        light: UIColor(hex: 0xFFFFFF)
    )


    // MARK: - Prestige

    /// Accent used sparingly for emphasis and AI-insight markers.
    static let prestige = dynamic(
        dark: 0xE2BB76,
        light: UIColor(hex: 0x285A8C)
    )

    static let prestigeGhost = dynamic(
        dark: 0xE2BB76,
        darkAlpha: 0.12,
        light: UIColor(hex: 0x285A8C).withAlphaComponent(0.10)
    )


    // MARK: - Brand
    // Dark mode keeps the navy / gold identity.

    /// Primary actions and strong brand elements.
    /// Never use for destructive actions.
    static let brandPrimary = accentFill

    /// Pressed / secondary brand states.
    static let brandSecondary = dynamic(
        dark: 0xF1D29A,
        light: UIColor(hex: 0x285A8C)
    )

    /// Main interactive accent.
    static let brandAccent = gold

    /// Subtle highlighted backgrounds and secondary buttons.
    static let brandAccentSoft = dynamic(
        dark: 0x29394D,
        light: .systemFill
    )

    /// Sparing emphasis.
    static let brandHighlight = prestige

    /// Soft brand tint for selected / branded fills.
    static let brandSoft = dynamic(
        dark: 0x29394D,
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
        light: UIColor(hex: 0x18724D)
    )


    // MARK: Warning / Yellow

    /// Attention required, but not necessarily negative.
    static let warning = dynamic(
        dark: 0xFFC94A,
        light: UIColor(hex: 0x946000)
    )

    static let warningSoft = dynamic(
        dark: 0xFFC94A,
        darkAlpha: 0.14,
        light: UIColor(hex: 0x946000).withAlphaComponent(0.12)
    )


    // MARK: Error / Red

    /// Errors, destructive states and negative meaning.
    static let error = dynamic(
        dark: 0xFF5C68,
        light: UIColor(hex: 0xBC3346)
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
        light: UIColor(hex: 0x18724D)
    )

    /// Subtle green fill behind positive content.
    static let positiveSoft = dynamic(
        dark: 0x42D98B,
        darkAlpha: 0.14,
        light: UIColor(hex: 0x18724D).withAlphaComponent(0.12)
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
        light: UIColor(hex: 0xBC3346)
    )

    /// Subtle red fill behind negative content.
    static let negativeSoft = dynamic(
        dark: 0xFF5C68,
        darkAlpha: 0.14,
        light: UIColor(hex: 0xBC3346).withAlphaComponent(0.12)
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
        light: UIColor(hex: 0xBC3346)
    )

    static let criticalSoft = dynamic(
        dark: 0xFF4055,
        darkAlpha: 0.20,
        light: UIColor(hex: 0xBC3346).withAlphaComponent(0.18)
    )


    // MARK: - UIKit-facing dynamic colors

    // Wrapped UIKit views can lose palette dynamism through a
    // UIColor(Color) bridge, so UIKit-facing colors are provided directly.

    static let uiTextBright = dynamicUIColor(
        dark: 0xF3F5F8,
        light: UIColor(hex: 0x182C46)
    )

    static let uiTextFaint = dynamicUIColor(
        dark: 0x8999AE,
        light: UIColor(hex: 0x60718A)
    )

    static let uiAccentFill = dynamicUIColor(
        dark: 0xE2BB76,
        light: UIColor(hex: 0x203E61)
    )

    static let uiTextOnAccent = dynamicUIColor(
        dark: 0x0C1420,
        light: UIColor(hex: 0xFFFFFF)
    )

    static let uiElevated = dynamicUIColor(
        dark: 0x202E40,
        light: UIColor(hex: 0xE8EEF5)
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

    /// State changes use one restrained timing and respect Reduce Motion.
    func subtleAnimation<Value: Equatable>(value: Value) -> some View {
        modifier(SubtleContentAnimation(value: value))
    }

    /// Inline navigation title with a secondary subtitle line under it.
    ///
    /// Used instead of `navigationSubtitle` (iOS 26-only) so title/subtitle
    /// pairs keep working on the app's deployment SDK.
    func navigationTitleWithSubtitle(_ title: String, subtitle: String, patient: Patient? = nil) -> some View {
        navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if let patient {
                        NavigationLink {
                            PatientDetailView(patient: patient)
                        } label: {
                            VStack(spacing: 1) {
                                Text(title).font(.headline).foregroundStyle(.primary).lineLimit(1)
                                HStack(spacing: 4) {
                                    Text(subtitle).lineLimit(1)
                                    Image(systemName: "chevron.forward")
                                }.font(.caption).foregroundStyle(Theme.gold)
                            }.frame(minHeight: 44)
                        }.buttonStyle(.plain)
                    } else {
                        VStack(spacing: 1) {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
    }

    /// Lays a scrolling screen (List/Form/ScrollView) on the Theme.base
    /// background instead of the system background.
    func themedScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.base.ignoresSafeArea())
    }

    /// Shared card surface; neutral outlines keep content and actions prominent.
    func themedCard(cornerRadius: CGFloat = 20, accent: Color = Theme.gold) -> some View {
        background(
            Theme.surface,
            in: RoundedRectangle(cornerRadius: cornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Theme.borderFaint, lineWidth: 0.75)
        )
    }
}

private struct SubtleContentAnimation<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: value)
    }
}
