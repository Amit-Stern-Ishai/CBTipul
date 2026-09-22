import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        let original = request.content
        guard let mutable = original.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(original)
            return
        }
        bestAttemptContent = mutable
        PatientPushPersonalizer.apply(to: mutable)
        contentHandler(mutable)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
