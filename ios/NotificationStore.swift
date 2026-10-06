import Foundation
import OSLog
import Supabase

/// Therapist Notification Center source of truth. Rows live on the server;
/// this type does not invent local history when the table is missing.
@Observable
@MainActor
final class NotificationStore {
    static private(set) var shared: NotificationStore?

    private let client: SupabaseClient
    private(set) var notifications: [AppNotification] = []
    private(set) var isLoading = false
    private var isRefreshing = false
    private var receiptWrites = 0
    private var generation = 0
    private(set) var didFailLastLoad = false
    /// Demo clinic must not show live therapist notifications.
    var isDemoInbox = false
    var patientModeActive = false

    /// Persistent rows the therapist has not opened (`readAt == nil`).
    var unreadCount: Int {
        NotificationCounts.unread(notifications)
    }

    /// Rows the therapist has not seen in the inbox (`seenAt == nil`).
    /// Drives the tab badge and in-app icon badge — not the same as `unreadCount`.
    var unseenCount: Int {
        NotificationCounts.unseen(notifications)
    }

    init(client: SupabaseClient) {
        self.client = client
        Self.shared = self
        UserDefaults.standard.removeObject(forKey: "cbtipul.notifications.inboxAcknowledgedCreatedAt")
    }

    func clear() {
        generation += 1
        notifications = []
        didFailLastLoad = false
        isLoading = false
        Task { await synchronizeAppIconBadge() }
    }

    #if DEBUG
    /// Offline regression fixtures, reachable only in the explicit UI-testing launch.
    func seedUITestingNotifications(patientID: String, questionnaireID: String?) {
        guard AuthManager.isUITesting, isDemoInbox,
              ProcessInfo.processInfo.arguments.contains("-UITestingNotifications") else { return }
        notifications = [
            AppNotification(id: UUID(), type: .questionnaireCompleted, patientId: patientID,
                            sessionId: nil, assignmentId: nil, resourceType: "questionnaire",
                            resourceId: questionnaireID, createdAt: Date(), seenAt: nil, readAt: nil),
            AppNotification(id: UUID(), type: .patientConnected, patientId: patientID,
                            sessionId: nil, assignmentId: nil, resourceType: nil,
                            resourceId: nil, createdAt: Date(), seenAt: nil, readAt: nil),
            AppNotification(id: UUID(), type: .diaryOneEntryAdded, patientId: "missing-test-patient",
                            sessionId: nil, assignmentId: nil, resourceType: nil,
                            resourceId: nil, createdAt: Date(), seenAt: nil, readAt: nil),
        ]
    }
    #endif

    func refresh(silently: Bool = false) async {
        guard !isRefreshing, receiptWrites == 0 else { return }
        let requestGeneration = generation
        isRefreshing = true
        defer { isRefreshing = false }
        guard !AuthManager.isUITesting else { return }
        if isDemoInbox {
            notifications = []
            didFailLastLoad = false
            isLoading = false
            await synchronizeAppIconBadge()
            return
        }
        if !silently {
            isLoading = true
            didFailLastLoad = false
        }
        defer { isLoading = false }
        guard SupabaseConfig.isConfigured else {
            notifications = []
            await synchronizeAppIconBadge()
            return
        }
        let recipientID: UUID
        do {
            recipientID = try await client.auth.session.user.id
        } catch {
            // A cancelled or transiently failed silent refresh must keep the
            // last successful inbox and badge, including during backgrounding.
            guard !silently, !Task.isCancelled else { return }
            didFailLastLoad = true
            await synchronizeAppIconBadge()
            return
        }
        do {
            let rows: [NotificationRow] = try await client.from("notifications")
                .select("id, type, patient_id, session_id, assignment_id, resource_type, resource_id, created_at, seen_at, read_at")
                .eq("recipient_user_id", value: recipientID.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            guard !Task.isCancelled, !isDemoInbox, requestGeneration == generation,
                  (try? await client.auth.session.user.id) == recipientID else { return }
            didFailLastLoad = false
            notifications = rows.map(\.asAppNotification)
            await synchronizeAppIconBadge()
        } catch {
            if !silently && !Task.isCancelled { didFailLastLoad = true }
            await synchronizeAppIconBadge()
            #if DEBUG
            AppLog.push.debug(
                "notifications refresh failed: \(error.localizedDescription, privacy: .public)"
            )
            #endif
        }
    }

    /// Marks currently unseen inbox rows as seen via `mark_notifications_seen`.
    /// Does not change `readAt`. No-ops when there is nothing unseen (avoids RPC loops).
    func markInboxSeen(force: Bool = false) async {
        while isRefreshing {
            do { try await Task.sleep(for: .milliseconds(25)) } catch { return }
        }
        receiptWrites += 1
        defer { receiptWrites -= 1 }
        guard force || unseenCount > 0 else { return }
        guard !isDemoInbox, !AuthManager.isUITesting else { return }
        guard SupabaseConfig.isConfigured else { return }
        do {
            try await client.rpc("mark_notifications_seen").execute()
            notifications = NotificationSeenAcknowledgement.applying(notifications, seenAt: Date())
            await synchronizeAppIconBadge()
        } catch {
            #if DEBUG
            AppLog.push.debug(
                "notifications mark-seen failed: \(error.localizedDescription, privacy: .public)"
            )
            #endif
        }
    }

    /// Persists `read_at` via `mark_notification_read`. Does not invent a local-only read.
    func markRead(_ notification: AppNotification) async {
        while isRefreshing {
            do { try await Task.sleep(for: .milliseconds(25)) } catch { return }
        }
        receiptWrites += 1
        defer { receiptWrites -= 1 }
        guard notification.isUnread else { return }
        guard !AuthManager.isUITesting, SupabaseConfig.isConfigured else { return }
        do {
            try await client.rpc(
                "mark_notification_read",
                params: MarkNotificationReadParams(pNotificationId: notification.id)
            )
            .execute()
            apply(notification.opened(at: Date()))
        } catch {
            #if DEBUG
            AppLog.push.debug(
                "notifications mark-read failed: \(error.localizedDescription, privacy: .public)"
            )
            #endif
        }
    }

    func markPatientResourceRead(patientID: UUID, messageID: UUID? = nil, assignmentID: UUID? = nil) async {
        for item in notifications where item.type.routesInPatientMode && item.patientId.flatMap(UUID.init(uuidString:)) == patientID {
            let matchesMessage = messageID != nil && item.type == .messageReceived && item.resourceType == "message" && item.resourceId.flatMap(UUID.init(uuidString:)) == messageID
            let matchesAssignment = assignmentID != nil && item.patientAssignmentType != nil && item.exactAssignmentID == assignmentID
            if matchesMessage || matchesAssignment { await markRead(item) }
        }
    }

    private func apply(_ notification: AppNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index] = notification
            Task { await synchronizeAppIconBadge() }
        }
    }

    /// App icon follows `unseenCount`. Failures here must not
    /// affect fetch or mark-read. Does not request notification permission.
    private func synchronizeAppIconBadge() async {
        await ApplicationIconBadge.sync(count: patientModeActive ? 0 : unseenCount)
    }
}

private nonisolated struct MarkNotificationReadParams: Encodable {
    let pNotificationId: UUID

    enum CodingKeys: String, CodingKey {
        case pNotificationId = "p_notification_id"
    }
}

private nonisolated struct NotificationRow: Decodable {
    let id: UUID
    let type: String
    let patientID: DatabaseID?
    let sessionID: DatabaseID?
    let assignmentID: DatabaseID?
    let resourceType: String?
    let resourceID: String?
    let createdAt: Date
    let seenAt: Date?
    let readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case patientID = "patient_id"
        case sessionID = "session_id"
        case assignmentID = "assignment_id"
        case resourceType = "resource_type"
        case resourceID = "resource_id"
        case createdAt = "created_at"
        case seenAt = "seen_at"
        case readAt = "read_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        patientID = try container.decodeIfPresent(DatabaseID.self, forKey: .patientID)
        sessionID = try container.decodeIfPresent(DatabaseID.self, forKey: .sessionID)
        assignmentID = try container.decodeIfPresent(DatabaseID.self, forKey: .assignmentID)
        resourceType = try container.decodeIfPresent(String.self, forKey: .resourceType)
        resourceID = Self.decodeFlexibleString(container, forKey: .resourceID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        seenAt = try container.decodeIfPresent(Date.self, forKey: .seenAt)
        readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
    }

    /// CombinedMood ids are numeric strings; other resources may be UUIDs.
    private static func decodeFlexibleString(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String? {
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? container.decodeIfPresent(Int64.self, forKey: key) {
            return String(value)
        }
        return nil
    }

    var asAppNotification: AppNotification {
        AppNotification(
            id: id,
            type: AppNotificationType(rawValue: type),
            patientId: patientID?.queryValue,
            sessionId: sessionID?.queryValue,
            assignmentId: assignmentID?.queryValue,
            resourceType: resourceType,
            resourceId: resourceID,
            createdAt: createdAt,
            seenAt: seenAt,
            readAt: readAt
        )
    }
}
