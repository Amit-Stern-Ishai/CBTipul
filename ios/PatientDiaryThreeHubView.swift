import OSLog
import SwiftUI

/// Patient Mode Diary 3 hub: history of patient-created entries, plus new entry.
struct PatientDiaryThreeHubView: View {
    var isActive: Bool
    var onAssignmentsRefresh: () async -> Void
    var onDiaryInactive: () async -> Void
    var onEntryVisibilityChange: (Bool) -> Void = { _ in }
    @State private var locallyInactive = false
    @State private var didSave = false
    @State private var isShowingEntry = false

    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var appContext

    private enum LoadState {
        case loading
        case loaded
        case failed
    }

    @State private var loadState: LoadState = .loading
    @State private var entries: [DiaryThreeEntry] = []

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
                    Text(L10n.diaryThreeLoadFailed)
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
                        Text(L10n.patientDiaryThreeDescription).font(.subheadline).foregroundStyle(Theme.textBody)
                        if PatientAssignmentType.diaryThreeSendingEnabled {
                            PatientToolStatusView(active: isActive && !locallyInactive)
                        } else {
                            Text(L10n.diaryThreeSendingPaused).foregroundStyle(Theme.textBody)
                        }
                        if loadState == .failed {
                            Text(L10n.diaryThreeLoadFailed).foregroundStyle(Theme.error)
                            Button(L10n.retryAction) { Task { await loadEntries() } }
                        }

                        Text(L10n.diaryOneMyEntriesTitle)
                            .font(.headline)
                            .foregroundStyle(Theme.textBright)
                            .padding(.top, 8)

                        if entries.isEmpty {
                            Text(L10n.diaryThreeEmptyTitle)
                                .font(.body)
                                .foregroundStyle(Theme.textBody)
                        } else {
                            ForEach(entries) { entry in
                                NavigationLink {
                                    PatientDiaryThreeDetailView(entry: entry)
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
        .navigationTitle(L10n.diaryThreeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if PatientAssignmentType.diaryThreeSendingEnabled && (loadState == .loaded || !entries.isEmpty) {
                Button { isShowingEntry = true } label: {
                    Text(L10n.diaryOneAddEntryAction)
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
        .navigationDestination(isPresented: $isShowingEntry) {
            PatientDiaryThreeEntryView(
                onSubmitted: {
                    didSave = true
                    await loadEntries()
                    await onAssignmentsRefresh()
                },
                onDiaryInactive: {
                    locallyInactive = true
                    await onDiaryInactive()
                },
                onVisibilityChange: onEntryVisibilityChange
            )
        }
        .safeAreaInset(edge: .top) {
            if didSave {
                Text(L10n.patientDiaryOneSaved).font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.success).padding(12)
                    .frame(maxWidth: .infinity).background(Theme.base)
            }
        }
        .task { await onAssignmentsRefresh(); await loadEntries() }
        .refreshable { await loadEntries(); await onAssignmentsRefresh() }
    }

    private func patientHistoryRow(_ entry: DiaryThreeEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.hebrewDateTime(entry.createdAt))
                .font(.headline)
                .foregroundStyle(Theme.textBright)
            Text(entry.situation)
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
            let loaded = try await PatientDiaryThreeService(client: auth.client)
                .loadPatientCreatedEntries(patientId: patientId)
            guard appContext.current?.patientId == patientId else { return }
            entries = loaded
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }
}

/// Read-only submitted Diary 3 entry in Patient Mode.
struct PatientDiaryThreeDetailView: View {
    let entry: DiaryThreeEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.hebrewDateTime(entry.createdAt))
                    .font(.headline)
                    .foregroundStyle(Theme.textBright)
                DiaryThreeEntryContent(entry: entry)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .patientAtmosphere(Theme.gold)
        .themedScreen()
        .navigationTitle(L10n.diaryThreeTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

}
