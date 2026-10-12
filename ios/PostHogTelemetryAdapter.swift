import Foundation

nonisolated struct PostHogSettings: Sendable {
    let token: String
    let host: String
    let enabled: Bool
    static let production = PostHogSettings(token: PostHogTelemetryConfiguration.projectToken,
        host: PostHogTelemetryConfiguration.host, enabled: PostHogTelemetryConfiguration.enabled)
    var valid: Bool { PostHogTelemetryConfiguration.valid(token: token, host: host) }
}
nonisolated struct PostHogManualEvent: @unchecked Sendable {
    let name: String
    let timestamp: Date
    let properties: [String: Any]
}

nonisolated enum PostHogEventMapper {
    static func name(_ event: TelemetryEvent) -> String {
        let stages: [TelemetryStage: String] = [.previewShown:"preview_shown",.roleSwitchConfirmed:"role_switch_confirmed",.shareSheetOpened:"share_sheet_opened",.sharingReported:"sharing_reported"]
        return "cbtipul_\(event.flow.rawValue)_\(stages[event.stage] ?? event.stage.rawValue)"
    }
    static func map(_ e: TelemetryEvent) -> PostHogManualEvent? {
        guard e.valid else { return nil }
        let m=e.metadata
        var p: [String:Any] = [
            "schema_version":e.schemaVersion,"correlation_id":e.correlationID.uuidString,
            "platform":m.platform,"device_model":m.deviceModel,
            "os_version":m.osVersion,"app_version":m.appVersion,"app_build":m.build,"build_channel":m.buildChannel,
            "distribution":m.distribution,"role":m.role.rawValue,"demo":m.demo,"network":m.network.rawValue,
            "lifecycle":m.lifecycle.rawValue,"locale":m.locale,"timezone":m.timezone,"flow":e.flow.rawValue,
            "stage":e.stage.rawValue,"outcome":e.outcome.rawValue,"safe_error_code":e.error.rawValue,
            "duration_ms":e.durationMs,"attempt":e.attempt,"retry_count":e.retryCount,
            "$process_person_profile":false,"$geoip_disable":true]
        p["manufacturer"]=m.manufacturer;p["api_level"]=m.apiLevel;p["method"]=e.method?.rawValue;p["form"]=e.form?.rawValue
        p["access"]=e.access?.rawValue;p["start"]=e.start?.rawValue;p["previous_role"]=e.previousRole?.rawValue
        p["push_operation"]=e.pushOperation?.rawValue;p["authorization"]=e.authorization?.rawValue;p["preference_enabled"]=e.preferenceEnabled
        p["apns_environment"]=e.apnsEnvironment?.rawValue;p["notification_type"]=e.notificationType?.rawValue
        p["logical_operation"]=e.request?.rawValue;p["http_status"]=e.httpStatus;p["feature"]=e.feature?.rawValue
        return PostHogManualEvent(name:name(e),timestamp:e.timestamp,properties:p)
    }
}

/// Stateless beforeSend property filter. SDK identity, timestamp and event UUID stay untouched.
nonisolated enum PostHogPrivacyGuard {
    static let customKeys: Set<String> = ["schema_version", "correlation_id", "platform", "device_model", "manufacturer", "api_level", "os_version", "app_version", "app_build", "build_channel", "distribution", "role", "demo", "network", "lifecycle", "locale", "timezone", "flow", "stage", "outcome", "safe_error_code", "duration_ms", "attempt", "retry_count", "feature", "method", "form", "access", "start", "previous_role", "push_operation", "authorization", "preference_enabled", "apns_environment", "notification_type", "logical_operation", "http_status"]
    static let sdkKeys: Set<String> = ["$lib", "$lib_version", "$session_id", "$device_id", "$is_identified"]
    static func filter(name: String, properties: [String: Any]) -> [String: Any]? {
        guard let flow = properties["flow"] as? String, TelemetryFlow(rawValue: flow) != nil,
              let stage = properties["stage"] as? String, let typedStage = TelemetryStage(rawValue: stage),
              name == "cbtipul_\(flow)_\(stageNames[typedStage] ?? stage)" else { return nil }
        var safe = properties.filter { key, value in
            guard customKeys.contains(key) || sdkKeys.contains(key) else { return false }
            if let allowed = enums[key] { return (value as? String).map(allowed.contains) ?? false }
            if ["correlation_id", "$session_id", "$device_id"].contains(key) {
                return (value as? String).flatMap(UUID.init(uuidString:)) != nil
            }
            if ["demo", "preference_enabled", "$is_identified"].contains(key) { return value is Bool }
            if let number = value as? NSNumber { return number.doubleValue.isFinite && number.doubleValue >= 0 && number.doubleValue <= 86_400_000 }
            if let string = value as? String { return !string.isEmpty && string.count <= 128 && string.range(of: "^[A-Za-z0-9 _./:()+-]+$", options: .regularExpression) != nil }
            return false
        }
        safe["$process_person_profile"] = false
        safe["$geoip_disable"] = true
        return safe
    }
    private static let stageNames: [TelemetryStage: String] = [.previewShown:"preview_shown",.roleSwitchConfirmed:"role_switch_confirmed",.shareSheetOpened:"share_sheet_opened",.sharingReported:"sharing_reported"]
    private static let enums: [String: Set<String>] = ["flow": Set(["authentication","restoration","access","invitation","submission","push","request","onboarding","sharing","assignment","message","ai"]),
"stage": Set(["started","succeeded","failed","cancelled","retry","received","previewShown","roleSwitchConfirmed","authorization","opened","shareSheetOpened","sharingReported","completed"]),
"outcome": Set(["started","succeeded","failed","cancelled","retrying","observed"]),
"feature": Set(["introduction","welcome","demoTour","displayName","invitationCreation","invitationShare","questionnaireAssignment","diaryAssignment","sendMessage","readMessage","messages","chat","transcription","sessionAnalysis","sessionPreparation","supervision","whatAmIMissing","caseReview"]),
"push_operation": Set(["permission","apnsRegistration","fcmRegistration","deviceRegistration","received","opened"]),
"logical_operation": Set(["appContext","invitationPreview","invitationClaim","questionnaireSubmit","diaryOneSubmit","diaryTwoSubmit","diaryThreeSubmit","pushDeviceRegister"]),
"platform": Set(["ios","android"]),
"build_channel": Set(["debug","release"]),
"distribution": Set(["unknown"]),
"role": Set(["therapist","patient","unknown"]),
"previous_role": Set(["therapist","patient","unknown"]),
"network": Set(["wifi","cellular","ethernet","other","offline","unknown"]),
"lifecycle": Set(["foreground","background","unknown"]),
"safe_error_code": Set(["none","generic","cancelled","timeout","network","unauthorized","forbidden","unavailable","unresolved"]),
"method": Set(["email","google","apple","anonymous"]),
"form": Set(["questionnaire","diaryOne","diaryTwo","diaryThree"]),
"access": Set(["full","read_only"]),
"start": Set(["cold","warm","unknown"]),
"authorization": Set(["allowed","denied","notDetermined","unknown"]),
"apns_environment": Set(["development","production","unknown"]),
"notification_type": Set(["questionnaire","diary","patientMessage","other","unknown"]),
"$lib": Set(["posthog-ios","posthog-android"])]
}
