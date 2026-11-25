import SwiftUI

struct ExposureAccessRow: View {
    let patientID: UUID
    let connected: Bool
    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var appContext
    @State private var enabled: Bool?
    @State private var busy = false
    @State private var error = false
    @State private var editor = false
    @State private var active = true
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("מדרג חשיפות") { editor = true }.font(BrandTypography.headline)
            if connected {
                if let enabled { Toggle("גישה למטופל/ת", isOn: Binding(get: { enabled }, set: { value in Task { await update(value) } })).disabled(busy) }
                if busy { ProgressView() }
                if error { Text("לא ניתן לעדכן את הגישה כרגע.").foregroundStyle(Theme.error); Button("ניסיון נוסף") { Task { await update(nil) } }.disabled(busy) }
            }
        }.sheet(isPresented: $editor) { ExposureHierarchyView(patientID: patientID.uuidString) }
        .task(id: auth.currentUserId) { active = true; if connected { await update(nil) } }
        .onDisappear { active = false }
    }
    @MainActor private func update(_ value: Bool?) async {
        guard !busy, let owner = auth.currentUserId else { return }; busy = true; error = false
        defer { if active && owner == auth.currentUserId { busy = false } }
        do {
            if let value {
                _ = try await appContext.getCurrentAppContext()
                guard owner == auth.currentUserId, EntitlementState.shared.allowMutation(allowLocalDemo: false) else { throw ExposureFailure.access }
                try await ExposureRequest.setEnabled(client: auth.client, patient: patientID, enabled: value)
            }
            let result = try await ExposureRequest.enabled(client: auth.client, patient: patientID)
            guard active, owner == auth.currentUserId else { return }; enabled = result
        } catch { if active && owner == auth.currentUserId { self.error = true } }
    }
}
