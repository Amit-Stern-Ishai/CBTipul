import OSLog
import SwiftUI

/// Patient Mode Diary 2 hub: history of patient-created entries, plus new entry.
struct PatientDiaryTwoHubView: View {
    var isActive: Bool
    var onAssignmentsRefresh: () async -> Void
    var onDiaryInactive: () async -> Void
    @State private var locallyInactive = false
    @State private var didSave = false

    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var appContext

    private enum LoadState {
        case loading
        case loaded
        case failed
    }

    @State private var loadState: LoadState = .loading
    @State private var entries: [DiaryTwoEntry] = []

    var body: some View {
        Group {
            switch loadState {
            case .loading where entries.isEmpty:
                ProgressView()
                    .tint(Theme.gold)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed where entries.isEmpty:
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.diaryTwoLoadFailed)
                        .font(.body)
                        .foregroundStyle(Theme.textBody)
                    Button(L10n.retryAction) {
                        Task { await loadEntries() }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .loading, .loaded, .failed:
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !isActive || locallyInactive { Text(L10n.patientDiaryTwoNotActive).foregroundStyle(.secondary) }
                        if loadState == .failed {
                            Text(L10n.diaryTwoLoadFailed).foregroundStyle(Theme.error)
                            Button(L10n.retryAction) { Task { await loadEntries() } }
                        }

                        Text(L10n.diaryOneMyEntriesTitle)
                            .font(.headline)
                            .foregroundStyle(Theme.textBright)
                            .padding(.top, 8)

                        if entries.isEmpty {
                            Text(L10n.diaryTwoEmptyTitle)
                                .font(.body)
                                .foregroundStyle(Theme.textBody)
                        } else {
                            ForEach(entries) { entry in
                                NavigationLink {
                                    PatientDiaryTwoDetailView(entry: entry)
                                } label: {
                                    patientHistoryRow(entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        }
        .patientAtmosphere(Theme.gold)
        .themedScreen()
        .navigationTitle(L10n.diaryTwoTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if loadState == .loaded || !entries.isEmpty {
                NavigationLink {
                    PatientDiaryTwoEntryView(
                        onSubmitted: {
                            didSave = true
                            await loadEntries()
                            await onAssignmentsRefresh()
                        },
                        onDiaryInactive: {
                            locallyInactive = true
                            await onDiaryInactive()
                        }
                    )
                } label: {
                    Text(entries.isEmpty ? L10n.emptyDiaryOnePrimaryAction : L10n.diaryOneAddEntryAction)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
                .buttonStyle(.pressableProminent)
                .controlSize(.large)
                .disabled(!isActive || locallyInactive)
                .entitlementCreateControl()
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Theme.base)
            }
        }
        .safeAreaInset(edge: .top) {
            if didSave {
                Text(L10n.patientDiaryOneSaved).font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.success).padding(12)
                    .frame(maxWidth: .infinity).background(Theme.base)
            }
        }
        .task { await loadEntries() }
        .refreshable { await loadEntries(); await onAssignmentsRefresh() }
    }

    private func patientHistoryRow(_ entry: DiaryTwoEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.hebrewDateTime(entry.createdAt))
                .font(.headline)
                .foregroundStyle(Theme.textBright)
            Text(entry.event)
                .font(.body)
                .foregroundStyle(Theme.textBody)
                .lineLimit(2)
            if !entry.automaticThoughtsPreview.isEmpty {
                Text(entry.automaticThoughtsPreview)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textBody)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func loadEntries() async {
        guard let patientId = appContext.current?.patientId else {
            loadState = .failed
            return
        }
        if entries.isEmpty {
            loadState = .loading
        }
        do {
            let loaded = try await PatientDiaryTwoService(client: auth.client)
                .loadPatientCreatedEntries(patientId: patientId)
            guard appContext.current?.patientId == patientId else { return }
            entries = loaded
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }
}

/// Read-only submitted Diary 2 entry in Patient Mode.
struct PatientDiaryTwoDetailView: View {
    let entry: DiaryTwoEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.hebrewDateTime(entry.createdAt))
                    .font(.headline)
                    .foregroundStyle(Theme.textBright)
                labeledBlock(L10n.diaryOneEventTitle, entry.event)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.diaryOneThoughtTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(entry.automaticThoughts.enumerated()), id: \.offset) { _, thought in
                        Text(thought)
                            .font(.body)
                            .foregroundStyle(Theme.textBright)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.diaryTwoFeelingsTitle).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(Array(entry.feelings.enumerated()), id: \.offset) { _, feeling in
                        Text("\(feeling.name) — \(feeling.intensity)%")
                    }
                }
                labeledBlock(L10n.diaryThinkingErrorsTitle, entry.thinkingErrors.map(\.title).joined(separator: "\n"))
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.diaryAlternativeThoughtsTitle).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(Array(entry.alternativeThoughts.enumerated()), id: \.offset) { _, thought in
                        Text(thought).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .patientAtmosphere(Theme.gold)
        .themedScreen()
        .navigationTitle(L10n.diaryTwoTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func labeledBlock(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .foregroundStyle(Theme.textBright)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

