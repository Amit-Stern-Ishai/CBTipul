import SwiftUI

struct PatientToolStatusView: View {
    let active: Bool

    private var color: Color { active ? Theme.success : Theme.textBody }

    var body: some View {
        Label(active ? L10n.patientToolEnabled : L10n.patientHistoryOnly,
              systemImage: active ? "checkmark.circle.fill" : "lock.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
