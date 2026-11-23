import SwiftUI
import Supabase

/// Optional discovery: device-local, account-scoped, never a consent or authorization gate.
@MainActor @Observable final class FeatureDiscovery {
    static let shared = FeatureDiscovery(storageURL: deviceURL)
    enum Milestone: String, Codable { case secondSession, diaryOne, diaryTwo
        var assignment: PatientAssignmentType {
            switch self { case .secondSession: .questionnaire; case .diaryOne: .diaryOne; case .diaryTwo: .diaryTwo }
        }
    }
    struct Intent: Codable, Identifiable, Equatable {
        var id = UUID()
        let account: String
        let feature: String
        let patient: DatabaseID
        var session: UUID? = nil
        var entry: UUID? = nil
        var reminder: Bool? = nil
        var context: String? = nil
    }
    private struct Display: Codable { var initial: Date; var reminderShown = false; var suppressed = false }
    private struct Ledger: Codable {
        var shown: Set<String> = []; var intents: [Intent] = []
        var displays: [String: Display]? = nil
        var voiceUsed: Set<String>? = nil
    }
    private let now: () -> Date
    private var parentContexts: [String: String] = [:]
    private(set) var activeContext: String? = nil
    func presentationOpportunity() { revision += 1 }
    func enterContext(_ context: String) {
        guard activeContext != context else { return }
        activeContext = context
        ledger.intents.removeAll { $0.reminder == true && $0.context != context }; persist()
    }
    func enterEditor(_ context: String, parent: String?) {
        if let parent, !parent.isEmpty { parentContexts[context] = parent }
        enterContext(context)
    }
    func returnAfterSave() {
        guard let current = activeContext, let parent = parentContexts[current] else { return }
        for i in ledger.intents.indices where ledger.intents[i].reminder == true && ledger.intents[i].context == current {
            ledger.intents[i].context = parent
        }
        activeContext = parent; persist()
    }
    func leaveContext(_ context: String) { if activeContext == context { enterContext("") } }
    func eligible(_ feature: String, account: String) -> Bool {
        _ = seen(feature, account: account)
        guard let display = ledger.displays?[key(feature, account)] else { return true }
        return !display.suppressed && !display.reminderShown &&
            !(feature == "voice" && (ledger.voiceUsed ?? []).contains(account.lowercased())) &&
            now().timeIntervalSince(display.initial) >= Double(feature == "invite" ? 3 : 7) * 86400
    }
    func valid(_ intent: Intent) -> Bool {
        guard ledger.intents.contains(where: { $0.id == intent.id }) else { return false }
        if intent.reminder == true { return intent.context == activeContext && eligible(intent.feature, account: intent.account) }
        return !seen(intent.feature, account: intent.account)
    }
    func suppress(_ feature: String, account: String) {
        let k = key(feature, account)
        var display = ledger.displays?[k] ?? Display(initial: now()); display.suppressed = true
        ledger.displays?[k] = display
        ledger.intents.removeAll { $0.account == account.lowercased() && $0.feature == feature }; persist()
    }
    func usedVoice(account: String) {
        ledger.voiceUsed = (ledger.voiceUsed ?? []).union([account.lowercased()])
        ledger.intents.removeAll { $0.account == account.lowercased() && $0.feature == "voice" && $0.reminder == true }; persist()
    }
    func presented(_ intent: Intent) {
        guard ledger.intents.contains(where: { $0.id == intent.id }), valid(intent) else { return }
        if intent.reminder == true {
            ledger.displays?[key(intent.feature, intent.account)]?.reminderShown = true
            ledger.intents.removeAll { $0.account == intent.account && $0.feature == intent.feature }; persist()
        } else { mark(intent.feature, account: intent.account) }
    }
    func presentedVoice(account: String, patient: DatabaseID?) {
        if let intent = pending(account: account).first(where: { $0.feature == "voice" && $0.patient == patient }) { presented(intent) }
    }
    private var ledger: Ledger
    private let defaults: UserDefaults
    private let storageURL: URL?
    private let therapist: @MainActor () -> Bool
    var saving = false
    var feedbackVisible = false
    var revision = 0
    var inlineVisible = false
    private var completedCreations: Set<String> = []
    private static var deviceURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeviceDiscovery/state.json")
    }
    init(defaults: UserDefaults = .standard, storageURL: URL? = nil,
         now: @escaping () -> Date = Date.init,
         therapist: @escaping @MainActor () -> Bool = { EntitlementState.shared.role == .therapist }) {
        self.now = now; self.defaults = defaults; self.storageURL = storageURL; self.therapist = therapist
        let data = storageURL.flatMap { try? Data(contentsOf: $0) } ?? defaults.data(forKey: "discovery.testLedger")
        ledger = data.flatMap { try? JSONDecoder().decode(Ledger.self, from: $0) } ?? Ledger()
        var displays = ledger.displays ?? [:]
        for key in ledger.shown where displays[key] == nil { displays[key] = Display(initial: now()) }
        ledger.displays = displays
        // A reminder requires a fresh action in this process, never a relaunch timer.
        ledger.intents.removeAll { $0.reminder == true }
        if !ledger.shown.isEmpty { persist() }
    }
    @discardableResult private func persist() -> Bool {
        revision += 1
        guard let data = try? JSONEncoder().encode(ledger) else { return false }
        guard let storageURL else { defaults.set(data, forKey: "discovery.testLedger"); return true }
        do {
            var directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
            try data.write(to: storageURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch { return false }
    }
    private func key(_ feature: String, _ account: String) -> String { "discovery.\(feature).\(account.lowercased())" }
    func seen(_ feature: String, account: String) -> Bool {
        if feature.contains("recentVisit") { return defaults.bool(forKey: key(feature, account)) }
        let canonical = feature.split(separator: ".").last.map(String.init) ?? feature
        let target = key(canonical, account)
        if ledger.shown.contains(target) { return true }
        // Carry forward actual legacy presentations, including any patient's milestone.
        let legacy = defaults.dictionaryRepresentation().filter { name, value in
            name.hasPrefix("discovery.") && name.hasSuffix(".\(account.lowercased())") &&
            (name == target || name.hasSuffix(".\(canonical).\(account.lowercased())")) && (value as? Bool == true)
        }
        if !legacy.isEmpty {
            ledger.shown.insert(target); ledger.displays?[target] = Display(initial: now()); let saved = persist()
            // New discovery state is deliberately excluded from cloud/device backups.
            if storageURL != nil && saved { for name in legacy.keys { defaults.removeObject(forKey: name) } }
            return true
        }
        return false
    }
    func mark(_ feature: String, account: String) {
        if feature.contains("recentVisit") { defaults.set(true, forKey: key(feature, account)); return }
        let canonical = feature.split(separator: ".").last.map(String.init) ?? feature
        let target = key(canonical, account)
        ledger.shown.insert(target)
        if ledger.displays?[target] == nil { ledger.displays?[target] = Display(initial: now()) }
        ledger.intents.removeAll { $0.account == account.lowercased() && $0.feature == canonical }
        persist()
    }
    func pending(account: String) -> [Intent] {
        ledger.intents.filter { $0.account == account.lowercased() && valid($0) }
    }
    func remove(_ intent: Intent) { ledger.intents.removeAll { $0.id == intent.id }; persist() }
    func enqueue(_ feature: String, account: String?, patient: DatabaseID, session: UUID? = nil, entry: UUID? = nil, demo: Bool, reminderOnly: Bool = false, initialOnly: Bool = false) {
        presentationOpportunity()
        guard !demo, !DemoData.isDemoID(patient), therapist(), let account, !account.isEmpty,
              eligible(feature, account: account),
              (!reminderOnly || seen(feature, account: account)), (!initialOnly || !seen(feature, account: account)),
              !ledger.intents.contains(where: { $0.account == account.lowercased() && $0.feature == feature && $0.patient == patient && $0.entry == entry }) else { return }
        let reminder = seen(feature, account: account)
        guard !reminder || !(activeContext ?? "").isEmpty else { return }
        ledger.intents.append(Intent(account: account.lowercased(), feature: feature, patient: patient, session: session, entry: entry, reminder: reminder, context: reminder ? activeContext : nil)); persist()
    }
    func requestMilestone(_ kind: Milestone, account: String?, patient: DatabaseID, entry: UUID? = nil, demo: Bool) {
        enqueue(kind.rawValue, account: account, patient: patient, entry: entry, demo: demo)
    }
    func requestWeb(account: String?, patient: DatabaseID, session: UUID, demo: Bool) {
        enqueue("web", account: account, patient: patient, session: session, demo: demo)
    }
    func sessionCreated(_ session: Session, patient: Patient, account: String?, demo: Bool) {
        guard !demo, let account, therapist(), patient.sessions.contains(where: { $0.id == session.id }),
              completedCreations.insert("\(account)/\(patient.id.queryValue)/\(session.id)").inserted else { return }
        var kinds = DiscoveryRules.sessionMilestones(type: session.type, matchingCount: patient.sessions.filter { $0.type == session.type }.count, total: patient.sessions.count)
        for kind in [Milestone.secondSession, .diaryOne, .diaryTwo] where seen(kind.rawValue, account: account) {
            if kind == .secondSession || (kind == .diaryOne && session.type == .diaryOne) || (kind == .diaryTwo && session.type == .diaryTwo) {
                if !kinds.contains(kind) { kinds.append(kind) }
            }
        }
        for kind in kinds {
            enqueue(kind.rawValue, account: account, patient: patient.id, session: session.id, demo: demo)
        }
    }
    func patientFeature(_ feature: String, patient: DatabaseID) -> String { "patient.\(patient.queryValue.lowercased()).\(feature)" }
    func beginPatientVisit(account: String, patient: DatabaseID) -> Bool {
        let feature = patientFeature("recentVisit", patient: patient)
        let visited = seen(feature, account: account); mark(feature, account: account); return visited
    }
    // Account switching clears presentation only. Durable intents remain isolated by owner.
    func clear() { enterContext(""); saving = false; feedbackVisible = false; inlineVisible = false }
}

enum DiscoveryRules {
    static func sessionMilestones(type: SessionType?, matchingCount: Int, total: Int) -> [FeatureDiscovery.Milestone] {
        var result: [FeatureDiscovery.Milestone] = []
        if matchingCount == 1, type == .diaryOne { result.append(.diaryOne) }
        if matchingCount == 1, type == .diaryTwo { result.append(.diaryTwo) }
        if total == 2 { result.append(.secondSession) }
        return result
    }
    /// Throws on unknown state; callers retain the intent for retry. nil means confirmed ineligible.
    @MainActor static func resolve(_ intent: FeatureDiscovery.Intent,
        firstEntry: () async throws -> Bool, sessionExists: () -> Bool,
        connected: () async throws -> Bool,
        enabled: (FeatureDiscovery.Milestone) async throws -> Bool) async throws -> Bool? {
        if intent.feature == "web" { return false } // A failed save still qualifies.
        if intent.entry != nil && intent.reminder != true { let first = try await firstEntry(); if !first { return nil } }
        if intent.session != nil, !sessionExists() { return nil }
        let linked = try await connected()
        if intent.feature == "invite" { return linked ? nil : true }
        guard let kind = FeatureDiscovery.Milestone(rawValue: intent.feature) else { return nil }
        let active = linked ? try await enabled(kind) : false
        return suggestion(connected: linked, enabled: active)
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
    var suppress: (() -> Void)? = nil
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
                    suppress: suppress.map { action in { action(); presented = false } }, dismiss: { presented = false })
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
    var suppress: (() -> Void)? = nil
    let dismiss: () -> Void
    @State private var copied = false
    private var symbol: String { web ? "laptopcomputer" : invite != nil ? "person.badge.plus" : "waveform" }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: web ? 14 : 18) {
                Image(systemName: symbol).font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Theme.textOnAccent).frame(width: web ? 56 : 72, height: web ? 56 : 72)
                    .background(Theme.accentFill, in: RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true)
                Text(title).font(BrandTypography.title2.bold()).foregroundStyle(Theme.textBright).accessibilityAddTraits(.isHeader)
                Text(bodyText).font(BrandTypography.body).foregroundStyle(Theme.textBody).fixedSize(horizontal: false, vertical: true)
                if web {
                    Text("cbtipul.com/app").font(BrandTypography.title3.weight(.semibold)).foregroundStyle(Theme.gold)
                        .textSelection(.enabled).environment(\.layoutDirection, .leftToRight)
                        .frame(maxWidth: .infinity).padding(16)
                        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 12))
                    Text(DiscoveryCopy.webDetail).font(BrandTypography.body).foregroundStyle(Theme.textBody)
                    if copied { Text("הכתובת הועתקה").font(BrandTypography.subheadline).foregroundStyle(Theme.success).accessibilityAddTraits(.updatesFrequently) }
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
                    if web, let suppress { Button("הבנתי, אל תציגו שוב", action: suppress).frame(minHeight: 44) }
                    Button("הבנתי", action: dismiss).frame(maxWidth: .infinity, minHeight: 44)
                } else { Button("הבנתי", action: dismiss).buttonStyle(.pressableProminent) }
            }.padding(.horizontal, 24).padding(.vertical, 12).background(Theme.surface)
        }
        .background(Theme.surface).tint(Theme.gold)
        .environment(\.layoutDirection, .rightToLeft)
        .appTextSize()
    }
}

/// One presentation slot below the mandatory therapist gates. Failed lookups remain queued.
struct WebDiscoveryHost: ViewModifier {
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(DiaryOneStore.self) private var one
    @Environment(DiaryTwoStore.self) private var two
    @State private var presented: FeatureDiscovery.Intent?
    @State private var invite = false
    private let discovery = FeatureDiscovery.shared
    private var currentOwner: String? { auth.currentUserId?.lowercased() }
    private var opportunityKey: String {
        "\(currentOwner ?? "")|\(scenePhase)|\(store.isDemoMode)|\(discovery.revision)|\(discovery.saving)|\(discovery.feedbackVisible)|\(discovery.inlineVisible)|\(presented?.id.uuidString ?? "")|\(store.discoveryPatientsLoaded)|\(EntitlementState.shared.role)|\(TherapistNotificationCoordinator.shared.isInboxShowingDetail)"
    }
    func body(content: Content) -> some View {
        content.overlay {
            if let pending = presented, pending.account == currentOwner, !store.isDemoMode {
                let milestone = FeatureDiscovery.Milestone(rawValue: pending.feature)
                DiscoveryCard(title: pending.feature == "web" ? DiscoveryCopy.webTitle : invite ? DiscoveryCopy.inviteTitle : L10n.discoveryActivitiesTitle,
                    bodyText: pending.feature == "web" ? DiscoveryCopy.webBody : invite ? DiscoveryCopy.inviteBody : L10n.discoveryActivityBody(milestone ?? .secondSession),
                    web: pending.feature == "web",
                    invite: pending.feature == "web" ? nil : {
                        presented = nil
                        guard pending.account == currentOwner else { return }
                        TherapistNotificationCoordinator.shared.openDiscovery(patientID: pending.patient, invitation: invite)
                    }, actionTitle: invite ? L10n.discoveryInviteAction : L10n.discoveryActivitiesAction,
                    onPresented: {
                        guard pending.account == currentOwner, scenePhase == .active, !store.isDemoMode, EntitlementState.shared.role == .therapist else { return }
                        discovery.presented(pending)
                    }, suppress: pending.feature == "web" ? { discovery.suppress("web", account: pending.account) } : nil, dismiss: { presented = nil })
                    .id(pending.id)
            }
        }
        .onChange(of: currentOwner) { _, _ in presented = nil; discovery.clear() }
        .onChange(of: store.isDemoMode) { _, _ in presented = nil }
        .onChange(of: scenePhase) { _, phase in if phase != .active { presented = nil } }
        .onChange(of: discovery.activeContext) { _, context in
            if let pending = presented, pending.reminder == true, pending.context != context { presented = nil }
        }
        .onChange(of: discovery.feedbackVisible) { _, visible in if visible { presented = nil } }
        .task(id: opportunityKey) {
            guard scenePhase == .active, !store.isDemoMode, let owner = currentOwner else { return }
                let modalController = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController?.presentedViewController
                // Native transition completion is an event, not a popup timer.
                if let transition = modalController?.transitionCoordinator {
                    transition.animate(alongsideTransition: nil) { _ in discovery.presentationOpportunity() }
                }
                let modal = modalController != nil
                let safe = presented == nil && !modal && TherapistNotificationCoordinator.shared.pendingPatientNavigation == nil && !TherapistNotificationCoordinator.shared.isInboxShowingDetail && !discovery.inlineVisible && !discovery.saving && !discovery.feedbackVisible &&
                    EntitlementState.shared.role == .therapist && owner == currentOwner
                if safe {
                    for pending in discovery.pending(account: owner) where pending.feature != "voice" {
                        guard let patient = store.patients.first(where: { $0.id == pending.patient }) else {
                            if store.discoveryPatientsLoaded { discovery.remove(pending) }
                            continue
                        }
                        do {
                            guard let id = patient.id.uuidValue else { discovery.remove(pending); continue }
                            let service = PatientAssignmentService(client: auth.client)
                            if pending.feature == "invite", pending.reminder == true {
                                struct Parameters: Encodable { let p_patient_id: String }
                                let status: String = try await auth.client.rpc("get_patient_email_invitation_status", params: Parameters(p_patient_id: id.uuidString)).execute().value
                                guard status == "no_invitation" else {
                                    if status == "pending" || status == "connected" { discovery.remove(pending) }
                                    continue
                                }
                            }
                            let suggestion = try await DiscoveryRules.resolve(pending, firstEntry: {
                                if pending.feature == "diaryOne" {
                                    let entries = try await one.loadEntries(for: patient.id)
                                    return entries.count == 1 && entries.first?.id == pending.entry
                                }
                                let entries = try await two.loadEntries(for: patient.id)
                                return entries.count == 1 && entries.first?.id == pending.entry
                            }, sessionExists: { patient.sessions.contains { $0.id == pending.session } },
                            connected: { try await service.isPatientConnected(patientId: id) },
                            enabled: { try await service.activeOngoingAssignment(patientId: id, type: $0.assignment) != nil })
                            guard let shouldInvite = suggestion else { discovery.remove(pending); continue }
                            try Task.checkCancellation()
                            let nowModal = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController?.presentedViewController != nil
                            guard owner == currentOwner, !store.isDemoMode, !nowModal, TherapistNotificationCoordinator.shared.pendingPatientNavigation == nil, !TherapistNotificationCoordinator.shared.isInboxShowingDetail, !discovery.saving, !discovery.feedbackVisible, !discovery.inlineVisible,
                                  EntitlementState.shared.role == .therapist, store.patients.contains(where: { $0.id == pending.patient }), discovery.valid(pending) else { break }
                            invite = shouldInvite; presented = pending; break
                        } catch is CancellationError { return }
                        catch { /* Retain for the next action or safe screen transition. */ }
                    }
                }
        }
    }
}

struct VoiceDiscoveryHint: View {
    let onPresented: () -> Void
    let dismiss: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "waveform").foregroundStyle(Theme.gold).accessibilityHidden(true)
            Text(DiscoveryCopy.voiceBody).font(BrandTypography.footnote).foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)
            Button("הבנתי", action: dismiss).font(BrandTypography.footnote.weight(.semibold)).frame(minHeight: 44)
        }.padding(12).background(Theme.elevated, in: RoundedRectangle(cornerRadius: 12)).tint(Theme.gold)
            .onAppear(perform: onPresented)
    }
}

#if DEBUG
/// Synthetic, opt-in UI review; no accounts, preference writes or network requests.
struct FeatureDiscoveryReview: View {
    @State private var kind = 0
    @State private var closed = false
    @State private var notes = ""
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
                    if kind == 1 {
                        TextField("סיכום הפגישה", text: $notes, axis: .vertical).textFieldStyle(.roundedBorder).accessibilityIdentifier("discovery.review.notes")
                        if !closed && !notes.isEmpty { VoiceDiscoveryHint(onPresented: {}, dismiss: { closed = true }) }
                    } else if !closed {
                        DiscoveryCard(title: kind == 0 ? DiscoveryCopy.inviteTitle : kind == 1 ? DiscoveryCopy.voiceTitle : DiscoveryCopy.webTitle,
                                      bodyText: kind == 0 ? DiscoveryCopy.inviteBody : kind == 1 ? DiscoveryCopy.voiceBody : DiscoveryCopy.webBody,
                                      web: kind == 2, invite: kind == 0 ? { closed = true } : nil, suppress: kind == 2 ? { closed = true } : nil) { closed = true }
                    } else { Text("ההסבר נסגר") }
                    }
                }.padding(20)
            }.background(Theme.base).navigationTitle("תצוגה סינתטית")
                .onChange(of: kind) { _, _ in closed = false }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}
#endif

/// Reminder intents belong to the visible screen; initial discovery can survive navigation.
struct DiscoveryContext: ViewModifier {
    @State private var token = UUID().uuidString
    @State private var parent = FeatureDiscovery.shared.activeContext
    func body(content: Content) -> some View {
        content.onAppear { FeatureDiscovery.shared.enterEditor(token, parent: parent) }
            .onDisappear { FeatureDiscovery.shared.leaveContext(token) }
    }
}
