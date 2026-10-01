import SwiftUI

struct AppVersionGateView<Content: View>: View {
    @State private var manager = AppVersionManager()
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if manager.checkingInitially && !AuthManager.isUITesting {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.base)
            } else if manager.decision == .required {
                AppUpdateNotice(required: true).appTextSize()
            } else {
                content()
            }
        }
        .environment(manager)
        .task { if !AuthManager.isUITesting { await manager.check(coldLaunch: true) } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !AuthManager.isUITesting { Task { await manager.check() } }
        }
    }
}

struct AppUpdateNotice: View {
    let required: Bool
    @Environment(AppVersionManager.self) private var manager
    @Environment(\.openURL) private var openURL
    @State private var storeFailed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if required {
                    Image(systemName: "arrow.down.app.fill").font(.system(size: 48)).foregroundStyle(Theme.gold)
                }
                Text(required ? L10n.updateRequiredTitle : L10n.updateOptionalTitle).font(.title2.bold())
                Text(required ? L10n.updateRequiredBody : L10n.updateOptionalBody).multilineTextAlignment(.center)
                if storeFailed { Text(L10n.updateStoreFailed).foregroundStyle(Theme.error) }
                Button(required ? L10n.updateRequiredAction : L10n.updateOptionalAction) {
                    guard let url = manager.policy?.validatedStoreURL else { return }
                    openURL(url) { accepted in storeFailed = !accepted }
                }.buttonStyle(.pressableProminent)
                if !required {
                    Button(L10n.updateLaterAction) { manager.dismissOptional() }.buttonStyle(.bordered)
                }
            }.padding(24).frame(maxWidth: .infinity)
        }
        .frame(maxHeight: required ? .infinity : 260)
        .background(Theme.base)
    }
}
