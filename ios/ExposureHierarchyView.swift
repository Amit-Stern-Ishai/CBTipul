import SwiftUI

struct ExposureHierarchyView: View {
    /// Nil is Patient Mode: the server derives the patient from the session.
    let patientID: String?
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var record: ExposureRecord?
    @State private var draft = ExposureDocument()
    @State private var backup: ExposureDocument?
    @State private var loaded = false
    @State private var active = true
    @State private var editing = false
    @State private var busy = false
    @State private var conflict = false
    @State private var denied = false
    @State private var error: String?
    @State private var message: String?
    @State private var confirm: String?
    private var dirty: Bool { loaded && draft != (record?.document ?? ExposureDocument()) }
    private var review: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-ExposureHierarchyReview")
#else
        false
#endif
    }
    private var canWrite: Bool { if review { return true }; return  patientID == nil ? EntitlementState.shared.canPatientWrite : (auth.isTherapistAuthenticated && EntitlementState.shared.canWrite) }
    var body: some View {
        NavigationStack {
            List {
                if busy { ProgressView() }
                if let error { Section { Text(error).foregroundStyle(Theme.error); Button(conflict ? "טעינת המדרג העדכני" : "ניסיון נוסף") { requestReload() }.disabled(busy) } }
                if backup != nil && !denied { Button("חזרה לשינויים שלי") { confirm = "backup" }.disabled(busy) }
                if loaded && !denied {
                    if editing { Text("לחצו לחיצה ארוכה על ידית השורה וגררו לשינוי הסדר.").font(BrandTypography.footnote).foregroundStyle(Theme.textBody) }
                    if draft.items.isEmpty && !editing { Text("אין עדיין מצבים במדרג.") }
                    ForEach($draft.items) { $item in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Text("\((draft.items.firstIndex(where: { $0.id == item.id }) ?? 0) + 1)").foregroundStyle(Theme.textBody); Spacer(); if !editing { Text(item.difficulty.map { "\($0)%" } ?? "טרם דורג").foregroundStyle(Theme.gold) } }
                            if editing {
                                TextField("המצב", text: $item.situation, axis: .vertical).lineLimit(2...8)
                                HStack { Text("רמת הקושי"); Spacer(); Text(item.difficulty.map { "\($0)%" } ?? "טרם דורג") }
                                Slider(value: Binding(get: { Double(item.difficulty ?? 50) }, set: { item.difficulty = Int($0) }), in: 0...100, step: 1).accessibilityLabel("רמת הקושי").accessibilityValue(item.difficulty.map { "\($0)%" } ?? "טרם דורג")
                                HStack {
                                    Button("ניקוי דירוג") { item.difficulty = nil }.disabled(item.difficulty == nil)
                                    Spacer()
                                    Button { move(item.id, delta: -1) } label: { Image(systemName: "arrow.up") }.accessibilityLabel("הזזה למעלה").disabled(draft.items.first?.id == item.id)
                                    Button { move(item.id, delta: 1) } label: { Image(systemName: "arrow.down") }.accessibilityLabel("הזזה למטה").disabled(draft.items.last?.id == item.id)
                                    Button(role: .destructive) { draft.items.removeAll { $0.id == item.id } } label: { Image(systemName: "trash") }.accessibilityLabel("מחיקת מצב")
                                }.buttonStyle(.borderless)
                            } else { Text(item.situation).fixedSize(horizontal: false, vertical: true).textSelection(.enabled) }
                        }
                        .padding(.vertical, 8).listRowBackground(Theme.surface)
                        .moveDisabled(!editing || busy).deleteDisabled(true)
                        .accessibilityAction(named: "הזזה למעלה") { if editing && !busy { move(item.id, delta: -1) } }
                        .accessibilityAction(named: "הזזה למטה") { if editing && !busy { move(item.id, delta: 1) } }
                    }.onMove { from, to in if editing && !busy { draft.items.move(fromOffsets: from, toOffset: to) } }
                    if editing {
                        Button { draft.items.append(ExposureItem()) } label: { Label("הוספת מצב", systemImage: "plus") }.disabled(draft.items.count >= 100)
                        if !draft.isValid { Text("יש לכתוב מצב בכל שורה (עד 1,000 תווים).").font(BrandTypography.footnote).foregroundStyle(Theme.error) }
                    }
                    if let message { Text(message).foregroundStyle(Theme.success) }
                }
            }
            .environment(\.editMode, .constant(editing ? .active : .inactive))
            .disabled(busy).listStyle(.insetGrouped).themedScreen()
            .navigationTitle("מדרג חשיפות").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("סגירה") { if dirty { confirm = "close" } else { dismiss() } }.disabled(busy) }
                ToolbarItem(placement: .primaryAction) {
                    if loaded && !denied && canWrite { Button(editing ? "שמירה" : "עריכה") { if editing { Task { await run("save") } } else { editing = true } }.disabled(busy || (editing && (!draft.isValid || conflict))) }
                }
                ToolbarItem(placement: .bottomBar) { if editing { Button("ביטול עריכה") { if dirty { confirm = "cancel" } else { editing = false } }.disabled(busy) } }
            }
        }
        .appTextSize().interactiveDismissDisabled(dirty || busy)
        .task { active = true; await run("load") }.onDisappear { active = false }
        .onChange(of: auth.currentUserId) { _, _ in active = false; dismiss() }
        .onChange(of: scenePhase) { _, phase in if phase == .active && patientID == nil { Task { await run("load", checkOnly: dirty) } } }
        .alert("יש שינויים שלא נשמרו", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } })) {
            Button("חזרה", role: .cancel) { confirm = nil }
            Button(confirm == "reload" ? "טעינת המדרג העדכני" : confirm == "backup" ? "חזרה לשינויים שלי" : "ויתור על השינויים", role: .destructive) {
                let action = confirm; confirm = nil
                if action == "reload" { backup = draft; Task { await run("load") } }
                else if action == "backup", let backup { draft = backup; self.backup = nil; editing = true }
                else if action == "close" { dismiss() }
                else { draft = record?.document ?? ExposureDocument(); editing = false; conflict = false; error = nil }
            }
        } message: { Text(confirm == "reload" ? "השינויים שלכם יישמרו כאן בנפרד." : "השינויים יוחלפו רק לאחר אישור.") }
    }
    private func move(_ id: UUID, delta: Int) { if let index = draft.items.firstIndex(where: { $0.id == id }) { draft.move(id, to: index + delta) } }
    private func requestReload() { if dirty { confirm = "reload" } else { Task { await run("load") } } }
    @MainActor private func run(_ action: String, checkOnly: Bool = false) async {
        guard !busy else { return }; if action == "save" && !canWrite { return }
        busy = true; error = nil; message = nil; let owner = auth.currentUserId
        defer { if active && owner == auth.currentUserId { busy = false } }
        do {
            let result: ExposureRecord
#if DEBUG
            if review { result = ExposureRecord(patient_id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!, document: action == "save" ? draft : ExposureDocument(items: [ExposureItem(situation: "לשאול שאלה בשיחה עם אדם מוכר", difficulty: 80), ExposureItem(situation: "להציג רעיון קצר בפני שני אנשים", difficulty: nil), ExposureItem(situation: "לצאת להליכה קצרה במקום מוכר", difficulty: 0)]), revision: "synthetic", updated_at: nil) } else { result = try await ExposureRequest.send(client: auth.client, action: action, patientID: patientID, revision: record?.revision, document: draft) }
#else
            result = try await ExposureRequest.send(client: auth.client, action: action, patientID: patientID, revision: record?.revision, document: draft)
#endif
            guard active, owner == auth.currentUserId else { return }
            denied = false
            if !checkOnly { record = result; draft = result.document ?? ExposureDocument(); loaded = true; conflict = false; editing = action == "load" && result.document == nil && canWrite }
            if action == "save" { message = "המדרג נשמר" }
#if DEBUG
            if action == "load" && review && ProcessInfo.processInfo.arguments.contains("-ExposureEditingReview") { editing = true }
#endif
        } catch is CancellationError {} catch {
            guard active, owner == auth.currentUserId else { return }
            conflict = (error as? ExposureFailure) == .conflict; denied = (error as? ExposureFailure) == .access
            self.error = conflict ? "המדרג השתנה במכשיר אחר. השינויים שלכם נשארו כאן." : denied ? "אין כרגע גישה למדרג. אפשר לבדוק שוב." : "לא ניתן לאשר שהפעולה הושלמה. השינויים נשארו כאן. אפשר לנסות שוב."
        }
    }
}
