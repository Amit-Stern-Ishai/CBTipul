import SwiftUI

/// The app's design system, resolved per the appearance setting:
///
/// - **Dark**: Navy-Midnight surfaces with a single gold accent.
/// - **Light**: the cool blue-tinted counterpart palette (same navy family).
/// - **System**: the native iOS palette (system backgrounds, labels and the
///   standard blue tint), following the device's light/dark setting.
///
/// Surfaces come only from the background stack (base → surface → elevated →
/// hover), depth comes from layering those levels (no gradients), and
/// semantic colors are used full-opacity for icons/text with ~10–12% tints
/// for fills.
enum Theme {
    // MARK: Background stack (cool blue-tinted in light — same family as dark)
    /// Page / screen background.
    static let base = dynamic(light: 0xF2F5FB, dark: 0x07080F, system: .systemGroupedBackground)
    /// Cards, sheets, side panels.
    static let surface = dynamic(light: 0xFAFBFE, dark: 0x0D1230, system: .secondarySystemGroupedBackground)
    /// Inputs, modals, dropdowns.
    static let elevated = dynamic(light: 0xE8EDF6, dark: 0x131A3C, system: .tertiarySystemFill)
    /// Row hover / selected states.
    static let hover = dynamic(light: 0xDDE3F2, dark: 0x1A2248, system: .systemFill)

    // MARK: Borders (navy-tinted in light, gold-tinted in dark)
    static let borderFaint = dynamic(light: 0x1E2C58, lightAlpha: 0.09, dark: 0xCFA038, darkAlpha: 0.10, system: .separator)
    static let borderDefault = dynamic(light: 0x1E2C58, lightAlpha: 0.09, dark: 0xCFA038, darkAlpha: 0.22, system: .separator)
    static let borderStrong = dynamic(light: 0x1E2C58, lightAlpha: 0.16, dark: 0xCFA038, darkAlpha: 0.45, system: .opaqueSeparator)

    // MARK: Text (medium navy values in light — never darker than Strong)
    /// Headings, primary body.
    static let textBright = Color(uiColor: uiTextBright)
    /// Secondary text, captions.
    static let textBody = dynamic(light: 0x505A88, dark: 0x8C8CA8, system: .secondaryLabel)
    /// Placeholder, disabled.
    static let textFaint = Color(uiColor: uiTextFaint)

    // MARK: Primary interactive accent
    // Gold in dark mode; in light mode navy carries buttons/fills and a
    // warm honey yellow carries the accent marks; system blue in System.
    /// Active labels, tinted icons, nav indicator — the text-weight accent.
    static let gold = dynamic(light: 0xD4AA30, dark: 0xCFA038, system: .systemBlue)
    /// Hover / focus state on accent elements.
    static let goldVivid = dynamic(light: 0xD4AA30, dark: 0xF2C050, system: .systemBlue)
    /// Pressed state.
    static let goldDim = dynamic(light: 0xB8902A, dark: 0x7A5C1A, system: .systemBlue)
    /// Tinted fills, pills.
    static let goldGhost = dynamic(light: 0xD4AA30, lightAlpha: 0.10, dark: 0xCFA038, darkAlpha: 0.12,
                                   system: .systemBlue.withAlphaComponent(0.12))
    /// Solid accent fills: primary buttons, avatars, selected fills.
    static let accentFill = dynamic(light: 0x1E2C58, dark: 0xCFA038, system: .systemBlue)
    /// Text and icons sitting on `accentFill`.
    static let textOnAccent = dynamic(light: 0xFAFBFE, dark: 0x07080F, system: .white)

    // MARK: Prestige honey (the light accent mark; plain gold in dark)
    static let prestige = dynamic(light: 0xD4AA30, dark: 0xCFA038, system: .systemBlue)
    static let prestigeGhost = dynamic(light: 0xD4AA30, lightAlpha: 0.10, dark: 0xCFA038, darkAlpha: 0.12,
                                       system: .systemBlue.withAlphaComponent(0.12))

    // MARK: Semantic (text/icons full opacity, fills at ~10–12%)
    static let success = dynamic(light: 0x326A50, dark: 0x3D7C5A, system: .systemGreen)
    static let warning = dynamic(light: 0x8A6418, dark: 0xB87820, system: .systemOrange)
    static let error = dynamic(light: 0x7A2838, dark: 0x7C2838, system: .systemRed)

    // MARK: UIKit-facing dynamic colors (for wrapped UIKit views, which
    // would lose the palette dynamism through a `UIColor(Color)` bridge).
    static let uiTextBright = dynamicUIColor(light: 0x1E2C58, dark: 0xF2EDE0, system: .label)
    static let uiTextFaint = dynamicUIColor(light: 0x8A94BC, dark: 0x3A3A54, system: .placeholderText)

    /// The palette currently selected in Settings. Read inside the dynamic
    /// providers so a palette change re-resolves every color (the root
    /// modifier re-identifies the view tree when it changes).
    private static var storedAppearance: AppAppearance {
        UserDefaults.standard.string(forKey: "appAppearance")
            .flatMap(AppAppearance.init(rawValue:)) ?? .dark
    }

    private static func dynamic(light: UInt32, lightAlpha: CGFloat = 1,
                                dark: UInt32, darkAlpha: CGFloat = 1,
                                system: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            if storedAppearance == .system {
                return system.resolvedColor(with: traits)
            }
            return traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark).withAlphaComponent(darkAlpha)
                : UIColor(hex: light).withAlphaComponent(lightAlpha)
        })
    }

    private static func dynamicUIColor(light: UInt32, dark: UInt32, system: UIColor) -> UIColor {
        UIColor { traits in
            if storedAppearance == .system {
                return system.resolvedColor(with: traits)
            }
            return UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
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
