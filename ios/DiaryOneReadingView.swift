import SwiftUI
struct DiaryOneReadingView: View {
 let patient: Patient
 let entryID: UUID
 @Environment(DiaryOneStore.self) private var diary
 @Environment(\.dismiss) private var dismiss
 private var entry: DiaryOneEntry? { diary.entries(for: patient.id).first { $0.id == entryID } }
 var body: some View {
  ScrollView { if let entry { VStack(alignment: .leading, spacing: 24) {
   Text(L10n.hebrewDateTime(entry.createdAt)).font(BrandTypography.subheadline).foregroundStyle(Theme.textBody)
   DiaryOneEntryContent(event: entry.event, automaticThoughts: entry.automaticThoughts, feelings: entry.feelings, behaviour: entry.behaviour, physicalSymptoms: entry.physicalSymptoms)
  }.padding(20).task(id: entry.id) {
   guard entry.createdBy == .patient, let key = DiaryNotificationKey(patientID: patient.id.queryValue, resourceType: "diary_one_entry", entryID: entry.id.uuidString) else { return }
   await NotificationStore.shared?.markDiaryEntryRead(key)
  } } }.themedScreen().navigationTitle(L10n.diaryOneTitle).navigationBarTitleDisplayMode(.inline)
  .toolbar { if let entry, EntitlementState.shared.canWrite { ToolbarItem(placement: .primaryAction) {
   NavigationLink { DiaryOneEntryFormView(patient: patient, mode: .edit(entry)).id(entry.updatedAt) } label: { Label(L10n.diaryEntryEdit, systemImage: "pencil") }
  } } }.onAppear { if entry == nil { dismiss() } }
 }
}
