import Foundation
import Network
import UIKit
import Darwin

/// Passive metadata only. No hardware ID, IP/SSID/carrier, or installed-app inventory.
nonisolated final class TelemetryPlatform: @unchecked Sendable {
    private static let shared = TelemetryPlatform()
    private let lock = NSLock()
    private var network: TelemetryNetwork = .unknown
    private var lifecycle: TelemetryLifecycle = .unknown
    private let monitor = NWPathMonitor()
    private var observers: [NSObjectProtocol] = []
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let category: TelemetryNetwork = path.status != .satisfied ? .offline :
                path.usesInterfaceType(.wifi) ? .wifi : path.usesInterfaceType(.cellular) ? .cellular :
                path.usesInterfaceType(.wiredEthernet) ? .ethernet : .other
            self?.lock.lock(); self?.network = category; self?.lock.unlock()
        }
        monitor.start(queue: DispatchQueue(label: "cbtipul.telemetry.metadata"))
    }
    @MainActor static func startLifecycleObservation() {
        let value = shared
        value.lock.lock(); value.lifecycle = UIApplication.shared.applicationState == .active ? .foreground : .background; value.lock.unlock()
        for (name, state) in [(UIApplication.didBecomeActiveNotification, TelemetryLifecycle.foreground),
                              (UIApplication.didEnterBackgroundNotification, TelemetryLifecycle.background)] {
            value.observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                value.lock.lock(); value.lifecycle = state; value.lock.unlock()
            })
        }
    }
    static func prime() { _ = shared }
    static func invitationStart() -> TelemetryStart { .unknown }
    static func snapshot() -> TelemetryMetadata {
        let value = shared
        var system = utsname(); uname(&system)
        let capacity = MemoryLayout.size(ofValue: system.machine)
        let model = withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: capacity) { String(cString: $0) }
        }
        value.lock.lock(); let network=value.network; let lifecycle=value.lifecycle; value.lock.unlock()
        #if DEBUG
        let channel = "debug"
        #else
        let channel = "release"
        #endif
        return TelemetryMetadata(platform: "ios", deviceModel: model.isEmpty ? "unknown" : model, manufacturer: nil,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString, apiLevel: nil,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            buildChannel: channel, distribution: "unknown", role: .unknown, network: network, lifecycle: lifecycle, locale: Locale.current.identifier, timezone: TimeZone.current.identifier)
    }
}
