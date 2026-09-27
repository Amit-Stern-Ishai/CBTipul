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
    }

    func refresh() async {
        guard !AuthManager.isUITesting else { return }
        if isDemoInbox {
            notifications = []
            didFailLastLoad = false
            isLoading = false
            return
        }
        isLoading = true
        didFailLastLoad = false
        defer { isLoading = false }
        guard SupabaseConfig.isConfigured else {
            notifications = []
            return
        }
        do {
            _ = try await client.auth.session
        } catch {
            notifications = []
            return
        }
        do {
            let rows: [NotificationRow] = try await client.from("notifications")
                .select("id, type, patient_id, session_id, assignment_id, resource_id, created_at, read_at")
                .order("created_at", ascending: false)
                .execute()
                .value
            notifications = rows.map(\.asAppNotification)
        } catch {
            didFailLastLoad = true
            notifications = []
            #if DEBUG
            AppLog.push.debug(
                "notifications refresh failed: \(error.localizedDescription, privacy: .public)"
            )
            #endif
        }
    }

    /// Persists `read_at` on the server. Does not invent a local-only read.
    func markRead(_ notification: AppNotification) async {
        guard notification.isUnread else { return }
        guard !AuthManager.isUITesting, SupabaseConfig.isConfigured else { return }
        do {
            let updated: [NotificationRow] = try await client.from("notifications")
                .update(NotificationReadUpdate(readAt: Date()))
                .eq("id", value: notification.id.uuidString)
                .is("read_at", value: nil)
                .select("id, type, patient_id, session_id, assignment_id, resource_id, created_at, read_at")
                .execute()
                .value
            if let row = updated.first {
                apply(row.asAppNotification)
            }
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
        }
    }
}

private nonisolated struct NotificationReadUpdate: Encodable {
    let readAt: Date

    enum CodingKeys: String, CodingKey {
        case readAt = "read_at"
    }
}

private nonisolated struct NotificationRow: Decodable {
    let id: UUID
    let type: String
    let patientID: DatabaseID?
    let sessionID: DatabaseID?
    let assignmentID: DatabaseID?
    let resourceID: DatabaseID?
    let createdAt: Date
    let readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case patientID = "patient_id"
        case sessionID = "session_id"
        case assignmentID = "assignment_id"
        case resourceID = "resource_id"
        case createdAt = "created_at"
        case readAt = "read_at"
    }

    var asAppNotification: AppNotification {
        AppNotification(
            id: id,
            type: AppNotificationType(rawValue: type),
            patientId: patientID?.queryValue,
            sessionId: sessionID?.queryValue,
            assignmentId: assignmentID?.queryValue,
            resourceId: resourceID?.queryValue,
            createdAt: createdAt,
            readAt: readAt
        )
    }
}
