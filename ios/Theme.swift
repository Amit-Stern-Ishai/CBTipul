import SwiftUI

/// The app's design system, resolved per the appearance setting:
///
/// - **Dark**: deep navy surfaces and turquoise accents.
/// - **Light**: the supplied CBTipul guide: white, pale blue, navy and turquoise.
///
/// Semantic colors are used full-opacity for icons/text with soft tints for
/// fills, never through color alone.
enum Theme {
    static var isPaper: Bool { storedAppearance == .light }
    static let historyBase = dynamic(dark: 0x213143, light: UIColor(hex: 0xE8F0F8))
    static let historyInk = dynamic(dark: 0xF3F7FA, light: UIColor(hex: 0x00244E))
    static let historyLow = dynamic(dark: 0x263F56, light: UIColor(hex: 0xD6EAF8))
    static let historyMedium = dynamic(dark: 0x355C78, light: UIColor(hex: 0xB6D8EB))
    static let historyHigh = dynamic(dark: 0x46728F, light: UIColor(hex: 0x85BBD7))
    static let patientHomeHeader = dynamic(dark: 0x0C304C, light: UIColor(hex: 0xD0F0FF))
    static let headerInk = dynamic(dark: 0xFFFFFF, light: UIColor(hex: 0x00244E))
    static let headerLine = dynamic(dark: 0xFFFFFF, darkAlpha: 0.22, light: UIColor(hex: 0xA3B1C2))


    // Source: צבעוניות-CBTipul.pdf. Entity tints identify record types, not clinical severity.
    static let turquoise = Color(uiColor: UIColor(hex: 0x00E3DB))
    static let turquoiseInk = Color(uiColor: UIColor(hex: 0x00244E))
    static let accentLine = dynamic(dark: 0x00E3DB, light: UIColor(hex: 0x008480))
    static let sessionTint = dynamic(dark: 0x182F50, light: UIColor(hex: 0xF2EFFF))
    static let sessionInk = dynamic(dark: 0x88B8FF, light: UIColor(hex: 0x235DB5))
    static let questionnaireTint = dynamic(dark: 0x103E3B, light: UIColor(hex: 0xD8FEF5))
    static let questionnaireInk = dynamic(dark: 0x8BDAC5, light: UIColor(hex: 0x356B53))
    static let diaryTint = dynamic(dark: 0x3A3222, light: UIColor(hex: 0xFFF5D5))
    static let diaryInk = dynamic(dark: 0xE5BD7C, light: UIColor(hex: 0x845921))
    // Full-fill severity badges always use navy ink; these are not text colors.
    static let severityMinimal = Color(uiColor: UIColor(hex: 0xB9FFEF))
    static let severityMild = Color(uiColor: UIColor(hex: 0xFFC516))
    static let severityModerate = Color(uiColor: UIColor(hex: 0xFF9C45))
    static let severitySevere = Color(uiColor: UIColor(hex: 0xFB513A))

    // MARK: - Background stack
    // Navy family in dark, cool neutral surfaces in light.

    /// Page / screen background.
    static let base = dynamic(
        dark: 0x071C2E,
        light: UIColor(hex: 0xFFFFFF)
    )

    /// Cards, sheets, side panels.
    static let surface = dynamic(
        dark: 0x0C2A44,
        light: UIColor(hex: 0xFFFFFF)
    )

    /// Inputs, modals, secondary grouped areas.
    static let elevated = dynamic(
        dark: 0x123751,
        light: UIColor(hex: 0xE8F0F8)
    )

    /// Row hover / selected states.
    static let hover = dynamic(
        dark: 0x19445F,
        light: UIColor(hex: 0xD6EAF8)
    )

    /// Featured / highlighted cards.
    static let surfaceWarm = dynamic(
        dark: 0x19445F,
        light: UIColor(hex: 0xE8F0F8)
    )


    // MARK: - Borders
    // Neutral outlines keep the accent reserved for actions and selection.

    static let borderFaint = dynamic(
        dark: 0x25465E,
        light: UIColor(hex: 0xDCE6EF)
    )

    static let borderDefault = dynamic(
        dark: 0x3C607A,
        light: UIColor(hex: 0xCBD5E1)
    )

    static let borderStrong = dynamic(
        dark: 0x7994AB,
        light: UIColor(hex: 0xA3B1C2)
    )


    // MARK: - Text

    /// Headings and primary body text.
    static let textBright = Color(uiColor: uiTextBright)

    /// Secondary text and captions.
    static let textBody = dynamic(
        dark: 0xB4C0D0,
        light: UIColor(hex: 0x5B6B82)
    )

    /// Tertiary text, placeholder and disabled states.
    static let textFaint = Color(uiColor: uiTextFaint)


    // MARK: - Interactive accent

    /// Turquoise in dark mode, navy for high-contrast light-mode links.
    ///
    /// Active labels, tinted icons and links.
    static let gold = dynamic(
        dark: 0x00E3DB,
        light: UIColor(hex: 0x0D3B66)
    )

    /// Hover / focus state on accent elements.
    static let goldVivid = dynamic(
        dark: 0x7CEEE8,
        light: UIColor(hex: 0x002B5D)
    )

    /// Pressed state of accent elements.
    static let goldDim = dynamic(
        dark: 0x00CCC7,
        light: UIColor(hex: 0x09345F)
    )

    /// Soft accent fills: secondary buttons, pills and highlighted icon chips.
    static let goldGhost = dynamic(
        dark: 0x00E3DB,
        darkAlpha: 0.12,
        light: UIColor(hex: 0x0D3B66).withAlphaComponent(0.10)
    )

    /// Solid brand fills: primary buttons, avatars and selected fills.
    static let accentFill = dynamic(
        dark: 0x00E3DB,
        light: UIColor(hex: 0x0D3B66)
    )

    /// Pressed state of `accentFill`.
    static let accentFillPressed = dynamic(
        dark: 0x00CCC7,
        light: UIColor(hex: 0x09345F)
    )

    /// Text and icons sitting on `accentFill`.
    static let textOnAccent = dynamic(
        dark: 0x071C2E,
        light: UIColor(hex: 0xFFFFFF)
    )


    // MARK: - Prestige

    /// Accent used sparingly for emphasis and AI-insight markers.
    static let prestige = dynamic(
        dark: 0x00E3DB,
        light: UIColor(hex: 0x0D3B66)
    )

    static let prestigeGhost = dynamic(
        dark: 0x00E3DB,
        darkAlpha: 0.12,
        light: UIColor(hex: 0x0D3B66).withAlphaComponent(0.10)
    )


    // MARK: - Brand
    // Both appearances use the supplied navy / turquoise identity.

    /// Primary actions and strong brand elements.
    /// Never use for destructive actions.
    static let brandPrimary = accentFill

    /// Pressed / secondary brand states.
    static let brandSecondary = dynamic(
        dark: 0x7CEEE8,
        light: UIColor(hex: 0x0D3B66)
    )

    /// Main interactive accent.
    static let brandAccent = gold

    /// Subtle highlighted backgrounds and secondary buttons.
    static let brandAccentSoft = dynamic(
        dark: 0x19445F,
        light: UIColor(hex: 0xE8F0F8)
    )

    /// Sparing emphasis.
    static let brandHighlight = prestige

    /// Soft brand tint for selected / branded fills.
    static let brandSoft = dynamic(
        dark: 0x19445F,
        light: UIColor(hex: 0xE8F0F8)
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
        dark: 0xB0C4D4,
        light: UIColor(hex: 0x5B6B82)
    )

    static let neutralMedium = dynamic(
        dark: 0x91ACBF,
        light: UIColor(hex: 0x5B6B82)
    )

    static let neutralSoft = dynamic(
        dark: 0xB0C4D4,
        darkAlpha: 0.10,
        light: UIColor(hex: 0xE8F0F8)
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
        light: UIColor(hex: 0x00244E)
    )

    static let uiTextFaint = dynamicUIColor(
        dark: 0x9CADBF,
        light: UIColor(hex: 0x5B6B82)
    )

    static let uiAccentFill = dynamicUIColor(
        dark: 0x00E3DB,
        light: UIColor(hex: 0x0D3B66)
    )

    static let uiTextOnAccent = dynamicUIColor(
        dark: 0x071C2E,
        light: UIColor(hex: 0xFFFFFF)
    )

    static let uiElevated = dynamicUIColor(
        dark: 0x123751,
        light: UIColor(hex: 0xE8F0F8)
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
                                Text(title).font(BrandTypography.headline).foregroundStyle(.primary).lineLimit(1)
                                HStack(spacing: 4) {
                                    Text(subtitle).lineLimit(1)
                                    Image(systemName: "chevron.forward")
                                }.font(BrandTypography.caption).foregroundStyle(Theme.gold)
                            }.frame(minHeight: 44)
                        }.buttonStyle(.plain)
                    } else {
                        VStack(spacing: 1) {
                            Text(title)
                                .font(BrandTypography.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(subtitle)
                                .font(BrandTypography.caption2)
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
            .tint(Theme.gold)
            .toolbarBackground(Theme.patientHomeHeader, for: .navigationBar)
    }

    /// Shared card surface; neutral outlines keep content and actions prominent.
    func themedCard(cornerRadius: CGFloat = 14, accent: Color = Theme.gold) -> some View {
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
