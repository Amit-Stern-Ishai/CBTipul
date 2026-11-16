import SwiftUI

/// Device-local discovery only. This is not consent or a processing gate.
@MainActor @Observable final class FeatureDiscovery {
    static let shared = FeatureDiscovery()
    struct Pending { let account: String; let patient: DatabaseID; let session: UUID }
    enum Milestone: String { case secondSession, diaryOne, diaryTwo
        var assignment: PatientAssignmentType {
            switch self { case .secondSession: .questionnaire; case .diaryOne: .diaryOne; case .diaryTwo: .diaryTwo }
        }
    }
    struct MilestonePending: Identifiable {
        let id = UUID()
        let account: String
        let patient: DatabaseID
        let milestone: Milestone
        let entry: UUID?
    }
    var milestone: MilestonePending?
    private var completedCreations: Set<String> = []
    func patientFeature(_ feature: String, patient: DatabaseID) -> String {
        "patient.\(patient.queryValue.lowercased()).\(feature)"
    }
    func beginPatientVisit(account: String, patient: DatabaseID) -> Bool {
        let feature = patientFeature("recentVisit", patient: patient)
        let visited = seen(feature, account: account)
        mark(feature, account: account)
        return visited
    }
    func requestMilestone(_ kind: Milestone, account: String?, patient: DatabaseID, entry: UUID? = nil, demo: Bool) {
        guard !demo, !DemoData.isDemoID(patient), therapist(),
              let account, !account.isEmpty, milestone == nil,
              !seen(patientFeature(kind.rawValue, patient: patient), account: account) else { return }
        web = nil // A milestone replaces workspace education for this save; never queue it behind the prompt.
        milestone = MilestonePending(account: account, patient: patient, milestone: kind, entry: entry)
    }
    func sessionCreated(_ session: Session, patient: Patient, account: String?, demo: Bool) {
        guard !demo, let account, therapist(),
              patient.sessions.contains(where: { $0.id == session.id }),
              completedCreations.insert("\(account)/\(patient.id.queryValue)/\(session.id)").inserted else { return }
        let kind = DiscoveryRules.sessionMilestone(type: session.type,
            matchingCount: patient.sessions.filter { $0.type == session.type }.count, total: patient.sessions.count)
        if let kind { requestMilestone(kind, account: account, patient: patient.id, demo: demo) }
    }
    var web: Pending?
    var saving = false
    var feedbackVisible = false
    private let defaults: UserDefaults
    private let therapist: @MainActor () -> Bool
    init(defaults: UserDefaults = .standard, therapist: @escaping @MainActor () -> Bool = { EntitlementState.shared.role == .therapist }) {
        self.defaults = defaults; self.therapist = therapist
    }
    func seen(_ feature: String, account: String) -> Bool { defaults.bool(forKey: "discovery.\(feature).\(account.lowercased())") }
    func mark(_ feature: String, account: String) { defaults.set(true, forKey: "discovery.\(feature).\(account.lowercased())") }
    func requestWeb(account: String?, patient: DatabaseID, session: UUID, demo: Bool) {
        guard !demo, let account, !account.isEmpty, !seen("web", account: account), web == nil, milestone == nil else { return }
        web = Pending(account: account, patient: patient, session: session)
    }
    func clear() { web = nil; milestone = nil; saving = false; feedbackVisible = false }
}

enum DiscoveryRules {
    static func sessionMilestone(type: SessionType?, matchingCount: Int, total: Int) -> FeatureDiscovery.Milestone? {
        if matchingCount == 1 {
            if type == .diaryOne { return .diaryOne }
            if type == .diaryTwo { return .diaryTwo }
        }
        return total == 2 ? .secondSession : nil
    }
    static func suggestion(connected: Bool?, enabled: Bool?) -> Bool? {
        guard let connected else { return nil }
        if !connected { return true } // Invite.
        guard enabled == false else { return nil }
        return false // Open activity settings.
    }
    static func voice(userEdit: Bool, nonempty: Bool, therapist: Bool, demo: Bool, seen: Bool) -> Bool {
        userEdit && nonempty && therapist && !demo && !seen
    }
    static func present(pending: Bool, busy: Bool, feedback: Bool, obstructed: Bool, valid: Bool) -> Bool {
        pending && !busy && !feedback && !obstructed && valid
    }
}

enum DiscoveryCopy {
    static let inviteTitle = "אפשר להזמין את המטופל/ת"
    static let inviteBody = "שלחו הזמנה לאפליקציה כדי שהמטופל/ת יוכל/תוכל למלא את הפעילויות שתפעילו עבורו/ה."
    static let voiceTitle = "אפשר גם להקליט"
    static let voiceBody = "אפשר גם להקליט את רשימות הפגישה. הדיבור מתומלל אוטומטית לטקסט, ואפשר לערוך אותו לאחר מכן."
    static let webTitle = "אפשר לעבוד גם מהמחשב"
    static let webBody = "פתחו במחשב הנייד או השולחני את:"
    static let webDetail = "התחברו עם אותו חשבון ובחרו מטופל/ת. אפשר לתעד פגישות ולמלא יחד שאלונים ויומנים, גם במהלך פגישת Zoom."
    static let url = "https://cbtipul.com/app"
}

struct DiscoveryCard: View {
    @Environment(\.dynamicTypeSize) private var textSize
    let title: String
    let bodyText: String
    var web = false
    var invite: (() -> Void)? = nil
    var actionTitle: String = L10n.discoveryInviteAction
    var onPresented: () -> Void = {}
    let dismiss: () -> Void
    @State private var presented = true
    @State private var choseInvite = false
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .sheet(isPresented: $presented, onDismiss: {
                if choseInvite, let invite { invite() } else { dismiss() }
            }) {
                DiscoveryPromptContent(title: title, bodyText: bodyText, web: web,
                    invite: invite == nil ? nil : { choseInvite = true; presented = false }, actionTitle: actionTitle,
                    dismiss: { presented = false })
                    .onAppear(perform: onPresented)
                    .presentationDetents(textSize.isAccessibilitySize ? [.large] : web ? [.height(550), .large] : [.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.surface)
            }
    }
}

private struct DiscoveryPromptContent: View {
    let title: String
    let bodyText: String
    let web: Bool
    var invite: (() -> Void)?
    var actionTitle: String
    let dismiss: () -> Void
    @State private var copied = false
    private var symbol: String { web ? "laptopcomputer" : invite != nil ? "person.badge.plus" : "waveform" }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: web ? 14 : 18) {
                Image(systemName: symbol).font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Theme.textOnAccent).frame(width: web ? 56 : 72, height: web ? 56 : 72)
                    .background(Theme.accentFill, in: RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true)
                Text(title).font(.title2.bold()).foregroundStyle(Theme.textBright).accessibilityAddTraits(.isHeader)
                Text(bodyText).font(.body).foregroundStyle(Theme.textBody).fixedSize(horizontal: false, vertical: true)
                if web {
                    Text("cbtipul.com/app").font(.title3.weight(.semibold)).foregroundStyle(Theme.gold)
                        .textSelection(.enabled).environment(\.layoutDirection, .leftToRight)
                        .frame(maxWidth: .infinity).padding(16)
                        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 12))
                    Text(DiscoveryCopy.webDetail).font(.body).foregroundStyle(Theme.textBody)
                    if copied { Text("הכתובת הועתקה").font(.subheadline).foregroundStyle(Theme.success).accessibilityAddTraits(.updatesFrequently) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(web ? 20 : 24).padding(.top, 12)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if web {
                    Button("העתקת כתובת") {
                        UIPasteboard.general.string = DiscoveryCopy.url; copied = true
                        UIAccessibility.post(notification: .announcement, argument: "הכתובת הועתקה")
                    }.buttonStyle(.pressableProminent)
                }
                if let invite { Button(actionTitle, action: invite).buttonStyle(.pressableProminent) }
                if web || invite != nil {
                    Button("הבנתי", action: dismiss).frame(maxWidth: .infinity, minHeight: 44)
                } else { Button("הבנתי", action: dismiss).buttonStyle(.pressableProminent) }
            }.padding(.horizontal, 24).padding(.vertical, 12).background(Theme.surface)
        }
        .background(Theme.surface).tint(Theme.gold)
        .environment(\.layoutDirection, .rightToLeft)
        .appTextSize()
    }
}

/// Lives only beneath the therapist gates; never presents over a modal or save feedback.
struct WebDiscoveryHost: ViewModifier {
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(DiaryOneStore.self) private var one
    @Environment(DiaryTwoStore.self) private var two
    @State private var milestoneAvailable = false
    @State private var inviteSuggestion: Bool?
    @State private var available = false
    private let discovery = FeatureDiscovery.shared
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if milestoneAvailable, let pending = discovery.milestone, let inviteSuggestion,
               pending.account == auth.currentUserId, !store.isDemoMode {
                DiscoveryCard(title: inviteSuggestion ? DiscoveryCopy.inviteTitle : L10n.discoveryActivitiesTitle,
                    bodyText: inviteSuggestion ? DiscoveryCopy.inviteBody : L10n.discoveryActivityBody(pending.milestone),
                    invite: {
                        discovery.milestone = nil
                        TherapistNotificationCoordinator.shared.openDiscovery(patientID: pending.patient, invitation: inviteSuggestion)
                    },
                    actionTitle: inviteSuggestion ? L10n.discoveryInviteAction : L10n.discoveryActivitiesAction,
                    onPresented: { discovery.mark(discovery.patientFeature(pending.milestone.rawValue, patient: pending.patient), account: pending.account) },
                    dismiss: { discovery.milestone = nil })
            } else if available, let pending = discovery.web, pending.account == auth.currentUserId, !store.isDemoMode {
                DiscoveryCard(title: DiscoveryCopy.webTitle, bodyText: DiscoveryCopy.webBody, web: true) { discovery.clear() }
                    .onAppear { discovery.mark("web", account: pending.account) }
            }
        }.onChange(of: milestoneAvailable) { wasAvailable, isAvailable in
            // If higher-priority feedback interrupts an already displayed prompt, do not re-present it.
            if wasAvailable && !isAvailable, let pending = discovery.milestone,
               discovery.seen(discovery.patientFeature(pending.milestone.rawValue, patient: pending.patient), account: pending.account) {
                discovery.milestone = nil
            }
        }.task(id: discovery.milestone?.id) {
            inviteSuggestion = nil
            guard let pending = discovery.milestone,
                  pending.account == auth.currentUserId, !store.isDemoMode,
                  EntitlementState.shared.role == .therapist,
                  let id = pending.patient.uuidValue else { return }
            do {
                if let entry = pending.entry {
                    let first: Bool
                    if pending.milestone == .diaryOne {
                        let entries = try await one.loadEntries(for: pending.patient)
                        first = entries.count == 1 && entries.first?.id == entry
                    } else {
                        let entries = try await two.loadEntries(for: pending.patient)
                        first = entries.count == 1 && entries.first?.id == entry
                    }
                    guard first else { if discovery.milestone?.id == pending.id { discovery.milestone = nil }; return }
                }
                let service = PatientAssignmentService(client: auth.client)
                let connected = try await service.isPatientConnected(patientId: id)
                let enabled = connected ? try await service.activeOngoingAssignment(patientId: id, type: pending.milestone.assignment) != nil : false
                try Task.checkCancellation()
                guard pending.account == auth.currentUserId, discovery.milestone?.id == pending.id,
                      store.patients.contains(where: { $0.id == pending.patient }), !store.isDemoMode else { return }
                inviteSuggestion = DiscoveryRules.suggestion(connected: connected, enabled: enabled)
                if inviteSuggestion == nil { discovery.milestone = nil }
            } catch {
                if discovery.milestone?.id == pending.id { discovery.milestone = nil }
            }
        }.task(id: "\(auth.currentUserId ?? "")-\(store.isDemoMode)-\(discovery.web?.session.uuidString ?? "")-\(discovery.milestone?.id.uuidString ?? "")-\(scenePhase)") {
            if (discovery.web != nil && discovery.web?.account != auth.currentUserId) || (discovery.milestone != nil && discovery.milestone?.account != auth.currentUserId) || store.isDemoMode { discovery.clear() }
            guard discovery.web != nil || discovery.milestone != nil else { available = false; milestoneAvailable = false; return }
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                let presented = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController?.presentedViewController != nil
                if let pending = discovery.web, !discovery.saving, !presented {
                    let valid = store.patients.first(where: { $0.id == pending.patient })?.sessions.contains(where: { $0.id == pending.session }) == true
                    if !valid { discovery.clear() }
                }
                milestoneAvailable = DiscoveryRules.present(pending: discovery.milestone != nil && inviteSuggestion != nil,
                    busy: discovery.saving, feedback: discovery.feedbackVisible, obstructed: presented && !milestoneAvailable,
                    valid: !store.isDemoMode && discovery.milestone?.account == auth.currentUserId && EntitlementState.shared.role == .therapist)
                available = discovery.milestone == nil && DiscoveryRules.present(pending: discovery.web != nil, busy: discovery.saving, feedback: discovery.feedbackVisible, obstructed: presented && !available, valid: !store.isDemoMode && discovery.web?.account == auth.currentUserId)
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
}

#if DEBUG
/// Synthetic, opt-in UI review; no accounts, preference writes or network requests.
struct FeatureDiscoveryReview: View {
    @State private var kind = 0
    @State private var closed = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if ProcessInfo.processInfo.arguments.contains("-MilestoneDiscoveryReview") {
                        if !closed {
                            DiscoveryCard(title: L10n.discoveryActivitiesTitle,
                                bodyText: L10n.discoveryActivityBody(.diaryOne), invite: { closed = true },
                                actionTitle: L10n.discoveryActivitiesAction, dismiss: { closed = true })
                        } else { Text("ההסבר נסגר") }
                    } else {
                    Picker("הסבר", selection: $kind) { Text("הזמנה").tag(0); Text("הקלטה").tag(1); Text("מחשב").tag(2) }.pickerStyle(.segmented)
                    if !closed {
                        DiscoveryCard(title: kind == 0 ? DiscoveryCopy.inviteTitle : kind == 1 ? DiscoveryCopy.voiceTitle : DiscoveryCopy.webTitle,
                                      bodyText: kind == 0 ? DiscoveryCopy.inviteBody : kind == 1 ? DiscoveryCopy.voiceBody : DiscoveryCopy.webBody,
                                      web: kind == 2, invite: kind == 0 ? { closed = true } : nil) { closed = true }
                    } else { Text("ההסבר נסגר") }
                    }
                }.padding(20)
            }.background(Theme.base).navigationTitle("תצוגה סינתטית")
                .onChange(of: kind) { _, _ in closed = false }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}
#endif
