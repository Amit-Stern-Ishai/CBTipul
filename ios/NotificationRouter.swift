import Foundation

/// Programmatic path on the Patients tab: Patient Detail → שאלונים
/// (and optionally the completed questionnaire).
struct PatientQuestionnairesRoute: Hashable {
    let patientID: DatabaseID
    let focusQuestionnaireID: DatabaseID?
}

/// Result of parsing a push or inbox record. Push taps and inbox taps share
/// this type so routing is not duplicated.
enum NotificationDestination: Equatable {
    /// Therapist Patients tab → patient → questionnaires → optional CombinedMood.
    case completedQuestionnaire(
        patientId: String,
        resourceType: String?,
        resourceId: String?
    )
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
        case .questionnaireAssigned, .unknown:
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
        execute(
            NotificationRouter.destination(from: notification),
            fingerprint: "inbox:\(notification.id.uuidString)",
            patients: patients,
            waitForPatients: false
        )
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
        switch destination {
        case .none:
            pendingPayload = nil
            lastConsumedFingerprint = fingerprint
        case .completedQuestionnaire(let patientId, let resourceType, let resourceId):
            guard let patient = patients.first(where: { $0.id.matches(patientId) }) else {
                if waitForPatients, !patientsLoadSettled {
                    return
                }
                pendingPayload = nil
                lastConsumedFingerprint = fingerprint
                selectedTab = .notifications
                return
            }
            pendingPayload = nil
            lastConsumedFingerprint = fingerprint
            selectedTab = .patients
            let focusID: DatabaseID?
            if resourceType == "questionnaire" {
                focusID = resourceId.flatMap(DatabaseID.parse)
            } else {
                focusID = nil
            }
            pendingPatientNavigation = PendingPatientNavigation(
                token: UUID(),
                route: PatientQuestionnairesRoute(
                    patientID: patient.id,
                    focusQuestionnaireID: focusID
                )
            )
        }
    }

    func consumePatientNavigation() -> PatientQuestionnairesRoute? {
        let pending = pendingPatientNavigation
        pendingPatientNavigation = nil
        return pending?.route
    }
}

struct PendingPatientNavigation: Equatable {
    let token: UUID
    let route: PatientQuestionnairesRoute
}
