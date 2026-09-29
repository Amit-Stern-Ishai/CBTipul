import Foundation
import OSLog

/// Programmatic path on the Patients tab: Patient Detail → שאלונים
/// (and optionally the completed questionnaire).
struct PatientQuestionnairesRoute: Hashable {
    let patientID: DatabaseID
    let focusQuestionnaireID: DatabaseID?

    var resultRoute: PatientQuestionnaireResultRoute? {
        focusQuestionnaireID.map { PatientQuestionnaireResultRoute(patientID: patientID, questionnaireID: $0) }
    }
}

/// Registered at the root stack so a notification can open the full path atomically.
struct PatientQuestionnaireResultRoute: Hashable {
    let patientID: DatabaseID
    let questionnaireID: DatabaseID
}

/// Programmatic path: Patient Detail → Diary 1 → optional exact entry.
struct PatientDiaryOneRoute: Hashable {
    let patientID: DatabaseID
    let focusEntryID: UUID?
}

/// Programmatic path: Patient Detail → Diary 2 → optional exact entry.
struct PatientDiaryTwoRoute: Hashable {
    let patientID: DatabaseID
    let focusEntryID: UUID?
}

/// Shared destination for push and persistent inbox taps.
enum NotificationDestination: Equatable {
    /// Therapist Patients tab → patient → questionnaires → optional CombinedMood.
    case completedQuestionnaire(
        patientId: String,
        resourceType: String?,
        resourceId: String?
    )
    /// Therapist Patients tab → patient → Diary 1 → optional exact entry.
    case diaryOneEntry(
        patientId: String,
        resourceType: String?,
        resourceId: String?
    )
    case diaryTwoEntry(patientId: String, resourceType: String?, resourceId: String?)
    /// Therapist Patients tab → Patient Detail. No session/questionnaire.
    case patientDetail(patientId: String)
    /// Unknown, Patient Mode, or missing identifiers — do not navigate.
    case none
}

enum NotificationRouter {
    static func destination(from payload: AppNotificationPayload) -> NotificationDestination {
        switch payload.type {
        case .questionnaireCompleted:
            guard let patientId = payload.patientId, !patientId.isEmpty else {
                return .none
            }
            return .completedQuestionnaire(
                patientId: patientId,
                resourceType: payload.resourceType,
                resourceId: payload.resourceId
            )
        case .diaryOneEntryAdded:
            guard let patientId = payload.patientId, !patientId.isEmpty else {
                return .none
            }
            return .diaryOneEntry(
                patientId: patientId,
                resourceType: payload.resourceType,
                resourceId: payload.resourceId
            )
        case .diaryTwoEntryAdded:
            guard let patientId = payload.patientId, !patientId.isEmpty else { return .none }
            return .diaryTwoEntry(patientId: patientId, resourceType: payload.resourceType, resourceId: payload.resourceId)
        case .patientConnected:
            guard let patientId = payload.patientId, !patientId.isEmpty else {
                return .none
            }
            return .patientDetail(patientId: patientId)
        case .questionnaireAssigned, .messageReceived, .diaryOneAssigned, .diaryTwoAssigned, .unknown:
            return .none
        }
    }

    static func destination(from notification: AppNotification) -> NotificationDestination {
        destination(from: .from(notification: notification))
    }
}

/// In-memory pending route + root tab selection. AppDelegate enqueues here
/// before therapist UI exists; `TherapistRootView` consumes once ready.
@Observable
@MainActor
final class TherapistNotificationCoordinator {
    static let shared = TherapistNotificationCoordinator()

    var selectedTab: TherapistRootTab = .patients
    var unavailableTarget = false
    private(set) var returnsToInbox = false
    private(set) var pendingPatientNavigation: PendingPatientNavigation?
    /// Bumps when a push tap is enqueued so the therapist shell can consume it.
    private(set) var pendingRevision = 0

    private var isTherapistRootReady = false
    private var patientsLoadSettled = false
    private var pendingPayload: AppNotificationPayload?
    private var lastConsumedFingerprint: String?

    private init() {}

    func markTherapistRootReady() {
        isTherapistRootReady = true
    }

    func markTherapistRootNotReady() {
        isTherapistRootReady = false
        patientsLoadSettled = false
    }

    func markPatientsLoadSettled() {
        patientsLoadSettled = true
    }

    func resetOnLogout() {
        unavailableTarget = false
        returnsToInbox = false
        pendingPayload = nil
        pendingPatientNavigation = nil
        lastConsumedFingerprint = nil
        isTherapistRootReady = false
        patientsLoadSettled = false
        selectedTab = .patients
    }

    /// APNs tap. Safe before auth/onboarding; executed once the therapist
    /// shell is ready.
    func handlePushTap(userInfo: [AnyHashable: Any]) {
        guard let payload = AppNotificationPayload.from(userInfo: userInfo) else { return }
        if lastConsumedFingerprint == payload.routingFingerprint { return }
        pendingPayload = payload
        pendingRevision += 1
    }

    /// Inbox row tap. Uses the same `NotificationRouter` as APNs.
    func handleInboxTap(_ notification: AppNotification, patients: [Patient]) {
        pendingPatientNavigation = nil
        unavailableTarget = false
        execute(
            NotificationRouter.destination(from: notification),
            fingerprint: "inbox:\(notification.id.uuidString)",
            patients: patients,
            waitForPatients: false
        )
        returnsToInbox = pendingPatientNavigation != nil
    }

    func finishInboxNavigation() {
        guard returnsToInbox else { return }
        returnsToInbox = false
        selectedTab = .notifications
    }

    func cancelInboxReturn() {
        returnsToInbox = false
    }

    func processPending(patients: [Patient]) {
        guard isTherapistRootReady, let payload = pendingPayload else { return }
        if lastConsumedFingerprint == payload.routingFingerprint {
            pendingPayload = nil
            return
        }
        execute(
            NotificationRouter.destination(from: payload),
            fingerprint: payload.routingFingerprint,
            patients: patients,
            waitForPatients: true
        )
    }

    private func execute(
        _ destination: NotificationDestination,
        fingerprint: String,
        patients: [Patient],
        waitForPatients: Bool
    ) {
        if waitForPatients { returnsToInbox = false }
        switch destination {
        case .none:
            pendingPayload = nil
            lastConsumedFingerprint = fingerprint
        case .patientDetail(let patientId):
            guard let patient = resolvedPatient(
                patientId: patientId,
                patients: patients,
                fingerprint: fingerprint,
                waitForPatients: waitForPatients
            ) else { return }
            pendingPayload = nil
            lastConsumedFingerprint = fingerprint
            selectedTab = .patients
            pendingPatientNavigation = PendingPatientNavigation(
                token: UUID(),
                patientID: patient.id,
                questionnairesRoute: nil,
                diaryOneRoute: nil
            )
            #if DEBUG
            AppLog.push.debug(
                "notification route patient_connected patient=\(patient.id.queryValue, privacy: .public)"
            )
            #endif
        case .completedQuestionnaire(let patientId, let resourceType, let resourceId):
            guard let patient = resolvedPatient(
                patientId: patientId,
                patients: patients,
                fingerprint: fingerprint,
                waitForPatients: waitForPatients
            ) else { return }
            pendingPayload = nil
            lastConsumedFingerprint = fingerprint
            selectedTab = .patients
            let focusID = QuestionnaireNotificationFocus.combinedMoodID(
                resourceType: resourceType,
                resourceId: resourceId
            )
            #if DEBUG
            AppLog.push.debug(
                "notification route questionnaire_completed patientId=\(patientId, privacy: .public) resourceType=\(resourceType ?? "nil", privacy: .public) resourceId=\(resourceId ?? "nil", privacy: .public) parsedCombinedMood=\(focusID?.queryValue ?? "nil", privacy: .public)"
            )
            #endif
            pendingPatientNavigation = PendingPatientNavigation(
                token: UUID(),
                patientID: patient.id,
                questionnairesRoute: PatientQuestionnairesRoute(
                    patientID: patient.id,
                    focusQuestionnaireID: focusID
                ),
                diaryOneRoute: nil
            )
            #if DEBUG
            AppLog.push.debug(
                "notification route created questionnaires patient=\(patient.id.queryValue, privacy: .public) focus=\(focusID?.queryValue ?? "nil", privacy: .public)"
            )
            #endif
        case .diaryTwoEntry(let patientId, let resourceType, let resourceId):
            guard let patient = resolvedPatient(patientId: patientId, patients: patients,
                fingerprint: fingerprint, waitForPatients: waitForPatients) else { return }
            pendingPayload = nil
            lastConsumedFingerprint = fingerprint
            selectedTab = .patients
            pendingPatientNavigation = PendingPatientNavigation(
                token: UUID(), patientID: patient.id, questionnairesRoute: nil, diaryOneRoute: nil,
                diaryTwoRoute: PatientDiaryTwoRoute(patientID: patient.id,
                    focusEntryID: DiaryTwoNotificationFocus.entryID(resourceType: resourceType, resourceId: resourceId)))
        case .diaryOneEntry(let patientId, let resourceType, let resourceId):
            guard let patient = resolvedPatient(
                patientId: patientId,
                patients: patients,
                fingerprint: fingerprint,
                waitForPatients: waitForPatients
            ) else { return }
            pendingPayload = nil
            lastConsumedFingerprint = fingerprint
            selectedTab = .patients
            let focusID = DiaryOneNotificationFocus.entryID(
                resourceType: resourceType,
                resourceId: resourceId
            )
            #if DEBUG
            AppLog.push.debug(
                "notification route diary_1_entry_added patientId=\(patientId, privacy: .public) resourceType=\(resourceType ?? "nil", privacy: .public) resourceId=\(resourceId ?? "nil", privacy: .public) parsedEntry=\(focusID?.uuidString ?? "nil", privacy: .public)"
            )
            #endif
            pendingPatientNavigation = PendingPatientNavigation(
                token: UUID(),
                patientID: patient.id,
                questionnairesRoute: nil,
                diaryOneRoute: PatientDiaryOneRoute(
                    patientID: patient.id,
                    focusEntryID: focusID
                )
            )
        }
    }

    /// Missing patient stays on Notifications after clinic load has settled.
    /// Cold-start waits until patients are available.
    private func resolvedPatient(
        patientId: String,
        patients: [Patient],
        fingerprint: String,
        waitForPatients: Bool
    ) -> Patient? {
        if let patient = patients.first(where: { $0.id.matches(patientId) }) {
            return patient
        }
        if waitForPatients, !patientsLoadSettled {
            return nil
        }
        pendingPayload = nil
        lastConsumedFingerprint = fingerprint
        selectedTab = .notifications
        unavailableTarget = true
        return nil
    }

    func consumePatientNavigation() -> PendingPatientNavigation? {
        let pending = pendingPatientNavigation
        pendingPatientNavigation = nil
        #if DEBUG
        if let pending {
            AppLog.push.debug(
                "notification route consumed patient=\(pending.patientID.queryValue, privacy: .public) questionnaires=\(pending.questionnairesRoute != nil, privacy: .public) diaryOne=\(pending.diaryOneRoute != nil, privacy: .public)"
            )
        }
        #endif
        return pending
    }
}

struct PendingPatientNavigation: Equatable {
    let token: UUID
    let patientID: DatabaseID
    /// When nil, open Patient Detail only (`patient_connected`).
    let questionnairesRoute: PatientQuestionnairesRoute?
    let diaryOneRoute: PatientDiaryOneRoute?
    var diaryTwoRoute: PatientDiaryTwoRoute? = nil
}
