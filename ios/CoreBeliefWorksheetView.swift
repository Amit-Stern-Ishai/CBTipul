import SwiftUI

struct CoreBeliefWorksheetView: View {
    let patientID: String?
    var readOnly = false
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var record: CoreBeliefWorksheetRecord?
    @State private var draft = CoreBeliefWorksheet()
    @State private var backup: CoreBeliefWorksheet?
    @State private var loaded = false
    @State private var active = true
    @State private var editing = false
    @State private var cancelEditing = false
    @State private var busy = false
    @State private var conflict = false
    @State private var message: String?
    @State private var error: String?
    @State private var discard = false
    @State private var reload = false
    private var dirty: Bool { loaded && draft != (record?.document ?? CoreBeliefWorksheet()) }
    private var canWrite: Bool { !readOnly && auth.isTherapistAuthenticated && EntitlementState.shared.canWrite }
    private var validDraft: Bool { (try? CoreBeliefWorksheetCodec.encodeDocument(draft)) != nil }
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
                    if loaded && readOnly && record?.document == nil { Text("עדיין לא נשלח עותק.").foregroundStyle(Theme.textBody) }
                    if loaded && (!readOnly || record?.document != nil) {
                        belief("אמונת היסוד הישנה", value: $draft.oldBelief)
                        belief("אמונת יסוד מאוזנת", value: $draft.balancedBelief)
                        textSection("הוכחות בעד האמונה הישנה", value: $draft.oldEvidence)
                        textSection("דרכים חלופיות להסתכל על הראיות", value: $draft.alternativeInterpretations)
                        textSection("הוכחות בעד האמונה המאוזנת", value: $draft.balancedEvidence)
                        textSection("התנהגות חדשה / ניסויים", value: $draft.experiments)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("דירוג מסכם").font(BrandTypography.headline)
                            rating("האמונה הישנה", value: $draft.finalOldRating)
                            rating("האמונה המאוזנת", value: $draft.finalBalancedRating)
                        }.padding(.vertical, 16)
                        if !readOnly {
                            if editing && !validDraft { Text("כל שדה יכול להכיל עד 10,000 תווים.").foregroundStyle(Theme.error) }
                            HStack {
                                if editing { Button("שמירה") { start("save") }.buttonStyle(.pressableProminent)
                                    .disabled(busy || !canWrite || !validDraft || (!dirty && record?.revision != nil)) }
                                Button("שליחת עותק למטופל/ת") { start("publish") }.buttonStyle(.bordered)
                                    .disabled(busy || !canWrite || dirty || record?.revision == nil || conflict)
                            }
                            if dirty { Text("יש לשמור את השינויים לפני השליחה.").font(BrandTypography.footnote).foregroundStyle(Theme.textBody) }
                            else if record?.revision != nil { Text(record?.publishedRevision == record?.revision ? "הגרסה השמורה נשלחה למטופל/ת" : record?.publishedRevision != nil ? "שינויים שמורים שטרם נשלחו" : "טרם נשלחה למטופל/ת").font(BrandTypography.footnote).foregroundStyle(Theme.textBody) }
                        }
                    }
                    if let message { Text(message).foregroundStyle(Theme.textBright).accessibilityAddTraits(.updatesFrequently) }
                }.padding(20)
            }
            .themedScreen()
            .navigationTitle("ערעור אמונת יסוד")
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
                Button("ביטול השינויים", role: .destructive) { draft = record?.document ?? CoreBeliefWorksheet(); editing = false; error = nil; conflict = false }
                Button("המשך עריכה", role: .cancel) {}
            }
            .confirmationDialog("לצאת בלי לשמור את השינויים?", isPresented: $discard, titleVisibility: .visible) { Button("יציאה ללא שמירה", role: .destructive) { dismiss() }; Button("המשך עריכה", role: .cancel) {} }
            .confirmationDialog("לטעון את הגרסה העדכנית? השינויים שלכם יישמרו כעותק כאן.", isPresented: $reload, titleVisibility: .visible) { Button("טעינה ושמירת עותק השינויים") { backup = draft; start(readOnly ? "load_published" : "load_draft") }; Button("ביטול", role: .cancel) {} }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .interactiveDismissDisabled(dirty || busy)
        .onDisappear { active = false }
        .onChange(of: patientID) { _, _ in active = false; dismiss() }
        .task { active = true; if !loaded { start(readOnly ? "load_published" : "load_draft") } }
        .onChange(of: auth.currentUserId) { _, _ in draft = CoreBeliefWorksheet(); backup = nil; record = nil; dismiss() }
    }
    private func belief(_ title: String, value: Binding<CoreBeliefWorksheet.Belief>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(BrandTypography.headline).foregroundStyle(Theme.textBright)
            textValue("האמונה", value: value.text)
            rating("עכשיו", value: value.now)
            rating("הכי הרבה", value: value.most)
            rating("הכי מעט", value: value.least)
            Text("רגשות").font(BrandTypography.callout).foregroundStyle(Theme.textBody)
            if editing && !readOnly { CoreBeliefFeelingsPicker(value: value.feelings).disabled(busy || !canWrite) } else { textValue("רגשות", value: value.feelings) }
        }.padding(.vertical, 16).overlay(alignment: .bottom) { Rectangle().fill(Theme.borderFaint).frame(height: 1) }
    }
    private func textSection(_ title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(BrandTypography.headline).foregroundStyle(Theme.textBright)
            textValue(title, value: value)
        }.padding(.vertical, 16).overlay(alignment: .bottom) { Rectangle().fill(Theme.borderFaint).frame(height: 1) }
    }
    @ViewBuilder private func textValue(_ title: String, value: Binding<String>) -> some View {
        if editing && !readOnly {
            TextField(title, text: value, axis: .vertical).font(BrandTypography.body).textFieldStyle(.plain).lineLimit(3...12)
                .foregroundStyle(Theme.textBright).padding(12).background(Theme.elevated, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel(title).disabled(busy || !canWrite)
        } else {
            Text(value.wrappedValue.isEmpty ? "לא מולא" : value.wrappedValue).font(BrandTypography.body)
                .foregroundStyle(Theme.textBody).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    @ViewBuilder private func rating(_ title: String, value: Binding<Int?>) -> some View {
        if editing && !readOnly {
            VStack(alignment: .leading, spacing: 4) {
                DiaryFeelingIntensityControl(intensity: value, title: title, requiresExplicitChoice: true)
                if value.wrappedValue != nil { Button("ניקוי דירוג") { value.wrappedValue = nil }.font(BrandTypography.caption) }
            }.disabled(busy || !canWrite)
        } else {
            HStack { Text(title).foregroundStyle(Theme.textBody); Spacer(); Text(value.wrappedValue.map { "\($0)%" } ?? "—").foregroundStyle(Theme.textBright) }
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
                if action == "save" || action == "publish" { guard canWrite else { throw CoreBeliefFailure.access } }
                let result = try await CoreBeliefRequest.send(client: auth.client, action: action, patientID: readOnly ? nil : patientID, revision: revision, document: value)
                guard active, owner != nil, owner == auth.currentUserId else { return }
                // Published reads must still belong to the linked patient that opened this screen.
                guard patientID == nil || result.patientId.lowercased() == patientID?.lowercased() else { throw CoreBeliefFailure.access }
                record = result; draft = result.document ?? CoreBeliefWorksheet(); loaded = true; conflict = false; editing = action == "load_draft" && result.document == nil && canWrite
                message = action == "save" ? "המסמך נשמר" : action == "publish" ? "המסמך נשלח למטופל/ת" : nil
            } catch {
                guard active, owner == auth.currentUserId else { return }
                conflict = (error as? CoreBeliefFailure) == .conflict
                self.error = conflict ? "המסמך השתנה במכשיר אחר. השינויים שלכם נשארו כאן." : (error as? CoreBeliefFailure) == .access ? "אין הרשאה לפעולה זו." : "לא ניתן לאשר שהפעולה הושלמה. השינויים נשארו כאן. אפשר לנסות שוב."
            }
        }
    }
}

private struct CoreBeliefFeelingsPicker: View {
    @Binding var value: String
    @State private var showing = false
    private var names: [String] { value.components(separatedBy: "\n").filter { !$0.isEmpty } }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                HStack {
                    Text(name).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button { var next = names; next.remove(at: index); value = next.joined(separator: "\n") } label: { Image(systemName: "xmark.circle") }.accessibilityLabel("הסרת רגש: " + name)
                }
            }
            Button("הוספת רגש", systemImage: "plus") { showing = true }
        }.sheet(isPresented: $showing) {
            DiaryFeelingPickerSheet(selectedNames: Set(names)) { name in
                guard !names.contains(name) else { return }
                value = (names + [name]).joined(separator: "\n")
            }
        }
    }
}
