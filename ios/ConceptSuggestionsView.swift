import SwiftUI
import Supabase

struct ConceptSuggestionsResponse: Decodable {
    let suggestions: [String]
    func validated() throws -> [String] {
        guard suggestions.count <= 4, suggestions.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.unicodeScalars.count <= 1500 }) else { throw ConceptFailure.failed }
        var seen = Set<String>(); return suggestions.filter { seen.insert($0).inserted }
    }
}
struct ConceptSuggestionRequest: Encodable {
    let patient_id: String
    let section: String
    let document: ConceptDocument
    let patient_context: String
}
struct ConceptSuggestionsView<Content: View>: View {
    let patientID: String?
    let section: ConceptSection
    let draft: ConceptDocument
    let disabled: Bool
    let add: ([String]) -> Void
    @ViewBuilder let content: () -> Content
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store
    @Environment(DiaryOneStore.self) private var diaryOne
    @Environment(DiaryTwoStore.self) private var diaryTwo
    @Environment(DiaryThreeStore.self) private var diaryThree
    @State private var suggestions: [String]?
    @State private var selected = Set<String>()
    @State private var loading = false
    @State private var error: String?
    @State private var request: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(section.title).font(BrandTypography.headline).foregroundStyle(Theme.textBright)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button { generate() } label: {
                    HStack(spacing: 5) {
                        if loading { ProgressView().controlSize(.mini) }
                        else { Image(systemName: "sparkles") }
                        Text("הצעות AI")
                    }
                    .font(BrandTypography.footnote)
                    .foregroundStyle(Theme.textBright)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 8))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(disabled || loading)
                    .accessibilityLabel("הצעות AI — \(section.title)")
                    .accessibilityValue(loading ? "מכינים הצעות" : "")
            }
            content()
            if let error { Text(error).foregroundStyle(Theme.error).font(BrandTypography.callout) }
            if let suggestions {
                if suggestions.isEmpty { Text("אין מספיק מידע להצעות").foregroundStyle(Theme.textBody) }
                else {
                    Text("הצעות לבדיקה — בחרו מה להוסיף").font(BrandTypography.footnote).foregroundStyle(Theme.textBody)
                    ForEach(suggestions, id: \.self) { text in
                        Button { if selected.contains(text) { selected.remove(text) } else { selected.insert(text) } } label: {
                            HStack(alignment: .top) { Image(systemName: selected.contains(text) ? "checkmark.square.fill" : "square"); Text(text).multilineTextAlignment(.leading); Spacer(minLength: 0) }.frame(minHeight: 44)
                        }.buttonStyle(.plain).foregroundStyle(Theme.textBright).accessibilityAddTraits(selected.contains(text) ? .isSelected : []).disabled(disabled)
                    }
                    Button("הוספת הנבחרות") { add(suggestions.filter { selected.contains($0) }); self.suggestions = nil; selected = [] }.buttonStyle(.bordered).disabled(disabled || selected.isEmpty || draft[section].count + selected.count > 30)
                }
            }
        }
        .onDisappear { request?.cancel(); request = nil; suggestions = nil }
        .onChange(of: auth.currentUserId) { _, _ in request?.cancel(); suggestions = nil; selected = []; error = nil }
    }
    private func generate() {
        guard !loading, !disabled, let patientID, let owner = auth.currentUserId,
              let patient = store.patients.first(where: { $0.id.queryValue.lowercased() == patientID.lowercased() }) else { return }
        loading = true; error = nil; suggestions = nil; selected = []
        let snapshot = draft
        request = Task { @MainActor in
            defer { if !Task.isCancelled { loading = false } }
            do {
                try await EntitlementState.shared.requireWrite()
                try await AIDataSharingConsentStore.ensureGranted()
                try Task.checkCancellation()
                guard owner == auth.currentUserId else { return }
                let questionnaires = try await store.loadQuestionnaires(for: patient)
                let one = try await diaryOne.loadEntries(for: patient.id)
                let two = try await diaryTwo.loadEntries(for: patient.id)
                let three = try await diaryThree.loadEntries(for: patient.id)
                let context = PatientAIContext.fullContext(patient: patient, questionnaires: questionnaires) + "\n\n" + PatientAIContext.diaryContext(one: one, two: two, three: three, unavailable: [])
                try Task.checkCancellation(); guard owner == auth.currentUserId else { return }
                try await EntitlementState.shared.requireWrite()
                let response: ConceptSuggestionsResponse = try await auth.client.functions.invoke("suggest-conceptualization-section", options: .init(body: ConceptSuggestionRequest(patient_id: patientID, section: section.rawValue, document: snapshot, patient_context: context)))
                try Task.checkCancellation(); guard owner == auth.currentUserId else { return }
                suggestions = try response.validated().filter { !snapshot[section].contains($0) }
            } catch is CancellationError { }
            catch is AIDataSharingConsentDeclinedError { }
            catch { if !Task.isCancelled && owner == auth.currentUserId { self.error = conceptSuggestionMessage(error) } }
        }
    }
}
func conceptSuggestionMessage(_ error: Error) -> String {
    if case let FunctionsError.httpError(status, data) = error {
        let detail = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = detail?["error"] as? String ?? detail?["code"] as? String ?? ""
        if status == 403 || status == 401 { return "אין הרשאה להצעות עבור המטופל/ת. חזרו לתיק ונסו שוב." }
        if status == 413 || ["input_too_large", "context_too_large", "payload_too_large"].contains(code) { return "המידע ארוך מדי לעיבוד. קצרו את הטיוטה ונסו שוב." }
        if ["AI_LIMIT_REACHED", "ai_quota_exceeded", "quota_exceeded", "monthly_limit_exceeded", "chat_tokens_exhausted", "AI_QUOTA_EXCEEDED", "THERAPIST_AI_QUOTA_EXCEEDED"].contains(code) || detail?["remainingTokens"] as? Int == 0 { return "מכסת ה־AI נוצלה. אפשר להמשיך לערוך ידנית ולנסות לאחר חידוש המכסה." }
        if status == 429 { return "נשלחו בקשות רבות. המתינו מעט ונסו שוב." }
    }
    return "לא הצלחנו לקבל הצעות. הטיוטה לא השתנתה. נסו שוב."
}
