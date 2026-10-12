/// Queued SDK notifications are observations, not authority to change identity.
enum AuthSessionObservation {
    static func isCurrent(_ observed: InvitationSession?, current: InvitationSession?) -> Bool {
        observed == current
    }
}
