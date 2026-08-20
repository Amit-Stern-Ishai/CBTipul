import SwiftUI

/// Shows a patient's status and links to their sessions, questionnaires,
/// and AI assistant.
struct PatientDetailView: View {
    @Bindable var patient: Patient

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    InitialsAvatar(name: patient.displayName, size: 72)
                    Text(patient.displayName)
                        .font(.title2.bold())
                    StatusBadge(status: patient.status)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                Picker(selection: $patient.status) {
                    ForEach(PatientStatus.allCases) { Text($0.rawValue).tag($0) }
                } label: {
                    iconChip("person.crop.circle.badge.checkmark", color: .green, title: "Status")
                }

                NavigationLink {
                    PatientSessionsView(patient: patient)
                } label: {
                    iconChip("calendar", color: .blue, title: "Sessions")
                }

                NavigationLink {
                    PatientQuestionnairesView(patient: patient)
                } label: {
                    iconChip("chart.xyaxis.line", color: .orange, title: QuestionnaireText.viewQuestionnairesAction)
                }

                NavigationLink {
                    PatientAIView(patient: patient)
                } label: {
                    iconChip("sparkles", color: .purple, title: QuestionnaireText.aiAction)
                }
            }
        }
        .navigationTitle(patient.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A Settings-style row label: a small tinted icon square next to the title.
    private func iconChip(_ systemImage: String, color: Color, title: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 7))
        }
    }
}

#Preview {
    let auth = AuthManager()
    NavigationStack {
        PatientDetailView(patient: Patient(firstName: "Alex", lastName: "Rivera", sessions: [Session()]))
    }
    .environment(PatientStore(client: auth.client))
}
