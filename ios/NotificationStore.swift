import Foundation
import OSLog
import Supabase
import UserNotifications

/// Therapist Notification Center source of truth. Rows live on the server;
/// this type does not invent local history when the table is missing.
@Observable
@MainActor
final class NotificationStore {
    static private(set) var shared: NotificationStore?

    private let client: SupabaseClient
    private(set) var notifications: [AppNotification] = []
    private(set) var isLoading = false
    private(set) var didFailLastLoad = false
    /// Demo clinic must not show live therapist notifications.
    var isDemoInbox = false

    var unreadCount: Int {
        notifications.reduce(0) { $0 + ($1.isUnread ? 1 : 0) }
    }

    init(client: SupabaseClient) {
        self.client = client
        Self.shared = self
    }

    func clear() {
        notifications = []
        didFailLastLoad = false
        isLoading = false
        synchronizeAppIconBadge()
    }

    func refresh() async {
        guard !AuthManager.isUITesting else { return }
        if isDemoInbox {
            notifications = []
            didFailLastLoad = false
            isLoading = false
            synchronizeAppIconBadge()
            return
        }
        isLoading = true
        didFailLastLoad = false
        defer { isLoading = false }
        guard SupabaseConfig.isConfigured else {
            notifications = []
            synchronizeAppIconBadge()
            return
        }
        do {
            _ = try await client.auth.session
        } catch {
            notifications = []
            synchronizeAppIconBadge()
            return
        }
        do {
            let rows: [NotificationRow] = try await client.from("notifications")
                .select("id, type, patient_id, session_id, assignment_id, resource_type, resource_id, created_at, read_at")
                .order("created_at", ascending: false)
                .execute()
                .value
            notifications = rows.map(\.asAppNotification)
            synchronizeAppIconBadge()
        } catch {
            didFailLastLoad = true
            notifications = []
            synchronizeAppIconBadge()
            #if DEBUG
            AppLog.push.debug(
                "notifications refresh failed: \(error.localizedDescription, privacy: .public)"
            )
            #endif
        }
    }

    /// Persists `read_at` via `mark_notification_read`. Does not invent a local-only read.
    func markRead(_ notification: AppNotification) async {
        guard notification.isUnread else { return }
        guard !AuthManager.isUITesting, SupabaseConfig.isConfigured else { return }
        do {
            try await client.rpc(
                "mark_notification_read",
                params: MarkNotificationReadParams(pNotificationId: notification.id)
            )
            .execute()
            apply(
                AppNotification(
                    id: notification.id,
                    type: notification.type,
                    patientId: notification.patientId,
                    sessionId: notification.sessionId,
                    assignmentId: notification.assignmentId,
                    resourceType: notification.resourceType,
                    resourceId: notification.resourceId,
                    createdAt: notification.createdAt,
                    readAt: Date()
                )
            )
        } catch {
            #if DEBUG
            AppLog.push.debug(
                "notifications mark-read failed: \(error.localizedDescription, privacy: .public)"
            )
            #endif
        }
    }

    private func apply(_ notification: AppNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index] = notification
            synchronizeAppIconBadge()
        }
    }

    /// App icon and tab badge share `unreadCount`. Failures here must not
    /// affect fetch or mark-read. Does not request notification permission.
    private func synchronizeAppIconBadge() {
        let count = unreadCount
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(count)
            } catch {
                #if DEBUG
                AppLog.push.debug(
                    "app icon badge sync failed: \(error.localizedDescription, privacy: .public)"
                )
                #endif
            }
        }
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
            readAt: readAt
        )
    }
}
