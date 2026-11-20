import SwiftUI

struct PatientConceptualizationView: View {
    let patientID: String?
    var readOnly = false
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var record: ConceptRecord?
    @State private var draft = ConceptDocument()
    @State private var backup: ConceptDocument?
    @State private var loaded = false
    @State private var editing = false
    @State private var cancelEditing = false
    @State private var busy = false
    @State private var conflict = false
    @State private var message: String?
    @State private var error: String?
    @State private var discard = false
    @State private var reload = false
    private var dirty: Bool { loaded && draft != (record?.document ?? ConceptDocument()) }
    private var canWrite: Bool { !readOnly && auth.isTherapistAuthenticated && EntitlementState.shared.canWrite }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if busy { ProgressView().frame(maxWidth: .infinity) }
                    if let error {
                        Text(error).foregroundStyle(Theme.error)
                        Button(conflict ? "טעינת הגרסה העדכנית" : "ניסיון נוסף") { requestReload() }.disabled(busy)
                    }
                    if backup != nil { Button("חזרה לשינויים שלי") { let previous = draft; draft = backup!; editing = true; backup = previous; message = "השינויים הוחזרו לעריכה. יש לשמור אותם." }.disabled(busy) }
                    if loaded && readOnly && record?.document == nil { Text("עדיין לא נשלחה המשגה.").foregroundStyle(Theme.textBody) }
                    if loaded && (!readOnly || record?.document != nil) {
                        if !editing && ConceptSection.allCases.allSatisfy({ draft[$0].isEmpty }) { Text("אין עדיין משפטים בהמשגה.").foregroundStyle(Theme.textBody) }
                        ForEach(ConceptSection.allCases, id: \.self) { section in
                            if editing || !draft[section].isEmpty { sectionView(section) }
                        }
                        if !readOnly {
                            if editing && !draft.isValid { Text("יש למלא כל משפט (עד 1,500 תווים), או להסיר משפט ריק.").foregroundStyle(Theme.error) }
                            HStack {
                                if editing { Button("שמירה") { start("save") }.buttonStyle(.pressableProminent)
                                    .disabled(busy || !canWrite || !draft.isValid || (!dirty && record?.revision != nil)) }
                                Button("שליחה למטופל/ת") { start("publish") }.buttonStyle(.bordered)
                                    .disabled(busy || !canWrite || dirty || record?.revision == nil || conflict)
                            }
                            if dirty { Text("יש לשמור את השינויים לפני השליחה.").font(BrandTypography.footnote).foregroundStyle(Theme.textBody) }
                            else if record?.revision != nil { Text(record?.published_revision == record?.revision ? "הגרסה השמורה נשלחה למטופל/ת" : record?.published_revision != nil ? "שינויים שמורים שטרם נשלחו" : "טרם נשלחה למטופל/ת").font(BrandTypography.footnote).foregroundStyle(Theme.textBody) }
                        }
                    }
                    if let message { Text(message).foregroundStyle(Theme.textBright).accessibilityAddTraits(.updatesFrequently) }
                }.padding(20)
            }
            .themedScreen()
            .navigationTitle("המשגה")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(Theme.isPaper ? .light : .dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("סגירה") { if dirty { discard = true } else { dismiss() } }.disabled(busy) }
                ToolbarItem(placement: .primaryAction) {
                    if canWrite && loaded { Button(editing ? "ביטול עריכה" : "עריכה") {
                        if editing { if dirty { cancelEditing = true } else { editing = false } } else { editing = true }
                    }.disabled(busy) }
                }
            }
            .confirmationDialog("לבטל את השינויים?", isPresented: $cancelEditing, titleVisibility: .visible) {
                Button("ביטול השינויים", role: .destructive) { draft = record?.document ?? ConceptDocument(); editing = false; error = nil; conflict = false }
                Button("המשך עריכה", role: .cancel) {}
            }
            .confirmationDialog("לצאת בלי לשמור את השינויים?", isPresented: $discard, titleVisibility: .visible) { Button("יציאה ללא שמירה", role: .destructive) { dismiss() }; Button("המשך עריכה", role: .cancel) {} }
            .confirmationDialog("לטעון את הגרסה העדכנית? השינויים שלכם יישמרו כעותק כאן.", isPresented: $reload, titleVisibility: .visible) { Button("טעינה ושמירת עותק השינויים") { backup = draft; start(readOnly ? "load_published" : "load_draft") }; Button("ביטול", role: .cancel) {} }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .interactiveDismissDisabled(dirty || busy)
        .task { if !loaded { start(readOnly ? "load_published" : "load_draft") } }
        .onChange(of: auth.currentUserId) { _, _ in draft = ConceptDocument(); backup = nil; record = nil; dismiss() }
    }
    private func sectionView(_ section: ConceptSection) -> some View {
        Group {
            if editing && !readOnly {
                ConceptSuggestionsView(patientID: patientID, section: section, draft: draft, disabled: busy || !canWrite, add: { values in
                    for value in values where draft[section].count < 30 && !draft[section].contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == value.trimmingCharacters(in: .whitespacesAndNewlines) }) { draft[section].append(value) }
                    message = nil
                }) { statements(section) }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text(section.title).font(BrandTypography.headline).foregroundStyle(Theme.textBright)
                    statements(section)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 16)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.borderFaint).frame(height: 1) }
    }
    private func statements(_ section: ConceptSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(draft[section].indices, id: \.self) { index in
                if !editing || readOnly {
                    Text("\(index + 1). \(draft[section][index])").font(BrandTypography.body).textSelection(.enabled).foregroundStyle(Theme.textBody)
                } else {
                    HStack(alignment: .top, spacing: 4) {
                        TextField("משפט", text: Binding(get: { draft[section].indices.contains(index) ? draft[section][index] : "" }, set: { if draft[section].indices.contains(index) { draft[section][index] = $0; message = nil } }), axis: .vertical)
                            .font(BrandTypography.body).textFieldStyle(.plain).lineLimit(2...10)
                            .foregroundStyle(Theme.textBright).padding(12)
                            .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityLabel("\(section.title), משפט \(index + 1)").disabled(busy || !canWrite)
                        Button { draft[section].remove(at: index) } label: { Image(systemName: "minus.circle").foregroundStyle(Theme.textBody).frame(minWidth: 44, minHeight: 44) }
                            .buttonStyle(.plain).accessibilityLabel("הסרת משפט \(index + 1)").disabled(busy || !canWrite)
                    }
                }
            }
            if editing && !readOnly {
                Button { draft[section].append("") } label: {
                    Label("הוספת משפט", systemImage: "plus").font(BrandTypography.callout).frame(minHeight: 44)
                }.buttonStyle(.plain).foregroundStyle(Theme.accentLine)
                    .disabled(busy || !canWrite || draft[section].count >= 30)
            }
        }
    }
    private func requestReload() { if dirty { reload = true } else { start(readOnly ? "load_published" : "load_draft") } }
    private func start(_ action: String) {
        guard !busy else { return }
        if readOnly && action != "load_published" { return }
        busy = true; error = nil; message = nil
        let owner = auth.currentUserId, revision = record?.revision, value = draft
        Task { @MainActor in
            defer { if owner == auth.currentUserId { busy = false } }
            do {
                if action == "save" || action == "publish" { guard canWrite else { throw ConceptFailure.access } }
                let result = try await ConceptRequest.send(client: auth.client, action: action, patientID: readOnly ? nil : patientID, revision: revision, document: value)
                guard owner != nil, owner == auth.currentUserId else { return }
                // Published reads must still belong to the linked patient that opened this screen.
                guard patientID == nil || result.patient_id.lowercased() == patientID?.lowercased() else { throw ConceptFailure.access }
                record = result; draft = result.document ?? ConceptDocument(); loaded = true; conflict = false; editing = false
                message = action == "save" ? "ההמשגה נשמרה" : action == "publish" ? "ההמשגה נשלחה למטופל/ת" : nil
            } catch {
                guard owner == auth.currentUserId else { return }
                conflict = (error as? ConceptFailure) == .conflict
                self.error = conflict ? "ההמשגה השתנתה במכשיר אחר. השינויים שלכם נשארו כאן." : (error as? ConceptFailure) == .access ? "אין הרשאה לפעולה זו." : "לא ניתן לאשר שהפעולה הושלמה. השינויים נשארו כאן. אפשר לנסות שוב."
            }
        }
    }
}
