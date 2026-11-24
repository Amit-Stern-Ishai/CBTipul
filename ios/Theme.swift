import SwiftUI

/// Neutral surfaces and brand blue; botanical green is reserved for success.

enum Theme {
    static var isPaper: Bool { true }
    static let historyBase = Color(uiColor: UIColor(hex: 0xF2F4F6))
    static let historyInk = Color(uiColor: UIColor(hex: 0x00244E))
    static let historyLow = Color(uiColor: UIColor(hex: 0xE8EEF5))
    static let historyMedium = Color(uiColor: UIColor(hex: 0xCDDFEF))
    static let historyHigh = Color(uiColor: UIColor(hex: 0xA5C3DE))
    static let patientHomeHeader = Color(uiColor: UIColor(hex: 0xFFFFFF))
    static let headerInk = Color(uiColor: UIColor(hex: 0x00244E))
    static let headerLine = Color(uiColor: UIColor(hex: 0x728399))

    static let turquoise = Color(uiColor: UIColor(hex: 0xE5EFF9))
    static let turquoiseInk = Color(uiColor: UIColor(hex: 0x00244E))
    static let accentLine = Color(uiColor: UIColor(hex: 0x285A8C))
    static let sessionTint = Color(uiColor: UIColor(hex: 0xE8F1F5))
    static let sessionInk = Color(uiColor: UIColor(hex: 0x365D70))
    static let questionnaireTint = Color(uiColor: UIColor(hex: 0xF2F4F6))
    static let questionnaireInk = Color(uiColor: UIColor(hex: 0x285A8C))
    static let diaryTint = Color(uiColor: UIColor(hex: 0xF7EFDF))
    static let diaryInk = Color(uiColor: UIColor(hex: 0x775B2A))
    static let severityMinimal = Color(uiColor: UIColor(hex: 0xDBEEE3))
    static let severityMild = Color(uiColor: UIColor(hex: 0xF4DFA4))
    static let severityModerate = Color(uiColor: UIColor(hex: 0xF0C49F))
    static let severitySevere = Color(uiColor: UIColor(hex: 0xEFB6B2))

    static let base = Color(uiColor: UIColor(hex: 0xF7F8FA))

    static let surface = Color(uiColor: UIColor(hex: 0xFFFFFF))

    static let elevated = Color(uiColor: UIColor(hex: 0xF2F4F6))

    static let hover = Color(uiColor: UIColor(hex: 0xE8EEF5))

    static let surfaceWarm = Color(uiColor: UIColor(hex: 0xF2F4F6))

    static let borderFaint = Color(uiColor: UIColor(hex: 0xDFE3E8))

    static let borderDefault = Color(uiColor: UIColor(hex: 0xB8C2CE))

    static let borderStrong = Color(uiColor: UIColor(hex: 0x728399))

    static let textBright = Color(uiColor: uiTextBright)

    static let textBody = Color(uiColor: UIColor(hex: 0x4B5E75))

    static let textFaint = Color(uiColor: uiTextFaint)

    static let gold = Color(uiColor: UIColor(hex: 0x285A8C))

    static let goldVivid = Color(uiColor: UIColor(hex: 0x235580))

    static let goldDim = Color(uiColor: UIColor(hex: 0x0D3B66))

    static let goldGhost = Color(uiColor: UIColor(hex: 0x285A8C).withAlphaComponent(0.10))

    static let accentFill = Color(uiColor: UIColor(hex: 0x285A8C))

    static let accentFillPressed = Color(uiColor: UIColor(hex: 0x0D3B66))

    static let textOnAccent = Color(uiColor: UIColor(hex: 0xFFFFFF))

    static let prestige = Color(uiColor: UIColor(hex: 0x285A8C))

    static let prestigeGhost = Color(uiColor: UIColor(hex: 0x285A8C).withAlphaComponent(0.10))

    static let brandPrimary = accentFill

    static let brandSecondary = Color(uiColor: UIColor(hex: 0x285A8C))

    static let brandAccent = gold

    static let brandAccentSoft = Color(uiColor: UIColor(hex: 0xF2F4F6))

    static let brandHighlight = prestige

    static let brandSoft = Color(uiColor: UIColor(hex: 0xF2F4F6))

    static let success = Color(uiColor: UIColor(hex: 0x28734E))

    static let warning = Color(uiColor: UIColor(hex: 0x886019))

    static let warningSoft = Color(uiColor: UIColor(hex: 0x886019).withAlphaComponent(0.12))

    static let error = Color(uiColor: UIColor(hex: 0xB33D49))

    static let positive = success

    static let positiveMedium = Color(uiColor: UIColor(hex: 0x28734E))

    static let positiveSoft = Color(uiColor: UIColor(hex: 0x28734E).withAlphaComponent(0.12))

    static let negative = error

    static let negativeMedium = Color(uiColor: UIColor(hex: 0xB33D49))

    static let negativeSoft = Color(uiColor: UIColor(hex: 0xB33D49).withAlphaComponent(0.12))

    static let neutral = Color(uiColor: UIColor(hex: 0x4B5E75))

    static let neutralMedium = Color(uiColor: UIColor(hex: 0x4B5E75))

    static let neutralSoft = Color(uiColor: UIColor(hex: 0xF2F4F6))

    static let critical = Color(uiColor: UIColor(hex: 0xB33D49))

    static let criticalSoft = Color(uiColor: UIColor(hex: 0xB33D49).withAlphaComponent(0.18))

    static let uiTextBright = UIColor(hex: 0x00244E)

    static let uiTextFaint = UIColor(hex: 0x4B5E75)

    static let uiAccentFill = UIColor(hex: 0x285A8C)

    static let uiTextOnAccent = UIColor(hex: 0xFFFFFF)

    static let uiElevated = UIColor(hex: 0xF2F4F6)

}

extension UIColor {

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

    func subtleAnimation<Value: Equatable>(value: Value) -> some View {
        modifier(SubtleContentAnimation(value: value))
    }

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

    func themedScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.base.ignoresSafeArea())
            .tint(Theme.gold)
            .toolbarBackground(Theme.patientHomeHeader, for: .navigationBar)
    }

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
