import Foundation
import SwiftUI

nonisolated enum EntitlementAccess: String, Codable, Sendable { case full, readOnly = "read_only" }
nonisolated struct AppEntitlement: Codable, Equatable, Sendable {
    let access: EntitlementAccess
    var canWrite: Bool { access == .full }
    var canUseAI: Bool { canWrite }
    var canPatientWrite: Bool { canWrite }
}

nonisolated struct EntitlementDenied: LocalizedError {
    let patient: Bool
    var errorDescription: String? { patient ? L10n.entitlementPatientUnavailable : L10n.entitlementReadOnlyExplanation }
}

/// One process-local permission owner. Unknown access never grants mutation rights.
@MainActor @Observable final class EntitlementState {
    static let shared = EntitlementState()
    private(set) var access: EntitlementAccess?
    private(set) var role: AppRole?
    private(set) var identity: String?
    var showExplanation = false
    private(set) var isLocalDemo = false
    var canWrite: Bool { access == .full || isLocalDemo }
    var canUseAI: Bool { access == .full }
    var canPatientWrite: Bool { access == .full }

    func setIdentity(_ id: String?) {
        guard id != identity else { return }
        PatientHomeCache.clear()
        identity = id; isLocalDemo = false; access = nil; role = nil; showExplanation = false
    }
    func apply(_ context: AppContext) {
        role = context.role
        access = context.isIncompletePatient ? nil : context.entitlement?.access
    }
    func invalidate() { access = nil }
    func clear() { PatientHomeCache.clear(); isLocalDemo = false; identity = nil; access = nil; role = nil; showExplanation = false }
    @discardableResult func allowMutation(allowLocalDemo: Bool = true) -> Bool {
        guard access == .full || (allowLocalDemo && isLocalDemo) else { showExplanation = true; return false }
        return true
    }
    func setLocalDemo(_ active: Bool) { isLocalDemo = active; showExplanation = false }
    func requireWrite(localDemo: Bool = false) throws {
        guard access == .full || (isLocalDemo && localDemo) else { throw EntitlementDenied(patient: role == .patient) }
    }
}

private struct EntitlementWriteModifier: ViewModifier {
    @State private var entitlement = EntitlementState.shared
    func body(content: Content) -> some View { content.disabled(!entitlement.canWrite) }
}
extension View {
    /// Apply only to mutation controls, never to a screen containing history/navigation.
    func entitlementWriteControl() -> some View { modifier(EntitlementWriteModifier()) }
}

/// Read-only long text remains selectable and scrollable.
struct EntitlementTextEditor: View {
    @Binding var text: String
    @State private var entitlement = EntitlementState.shared
    var body: some View {
        if entitlement.canWrite { TextEditor(text: $text) }
        else { ScrollView { Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(5) } }
    }
}

/// Creation stays visibly unavailable, but its replacement hit target explains why.
private struct EntitlementCreateModifier: ViewModifier {
    @State private var entitlement = EntitlementState.shared
    @State private var explaining = false
    func body(content: Content) -> some View {
        content
            .disabled(!entitlement.canWrite)
            .opacity(entitlement.canWrite ? 1 : 0.45)
            .accessibilityHidden(!entitlement.canWrite)
            .overlay {
                if !entitlement.canWrite {
                    Button { explaining = true } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(entitlement.role == .patient ? L10n.entitlementPatientUnavailable : L10n.entitlementReadOnlyTitle)
                }
            }
            .alert(entitlement.role == .patient ? L10n.entitlementPatientUnavailable : L10n.entitlementReadOnlyTitle,
                   isPresented: $explaining) {
                Button(L10n.ok, role: .cancel) {}
            } message: {
                Text(entitlement.role == .patient ? L10n.entitlementPatientUnavailable : L10n.entitlementReadOnlyExplanation)
            }
    }
}
extension View {
    func entitlementCreateControl() -> some View { modifier(EntitlementCreateModifier()) }
}
