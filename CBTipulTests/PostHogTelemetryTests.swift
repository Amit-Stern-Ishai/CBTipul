import Foundation
import Testing
@testable import CBTipul

struct PostHogTelemetryTests {
    @Test func missingConfigurationIsHarmless() {
        #expect(!PostHogTelemetryConfiguration.valid(token:"",host:"https://eu.i.posthog.com"))
        #expect(!PostHogTelemetryConfiguration.valid(token:"phx_personal",host:"https://eu.i.posthog.com"))
        #expect(!PostHogTelemetryConfiguration.valid(token:"phc_synthetic",host:"https://us.i.posthog.com"))
    }
    @Test func statelessFilterDropsSensitivePropertiesAndAutomaticEvents() {
        let session=UUID().uuidString
        let raw:[String:Any] = ["flow":"access","stage":"failed","role":"therapist","safe_error_code":"unresolved", "$session_id":session, "$device_id":UUID().uuidString,"$lib":"posthog-ios","$lib_version":"3.92.0", "$device_name":"private phone name", "patient_id":"clinical-id", "email":"private@example.com", "note":"private clinical text", "$set":["email":"private"], "unexpected":"anything", "$exception_list":["raw"]]
        let safe=PostHogPrivacyGuard.filter(name:"cbtipul_access_failed",properties:raw)!
        #expect(safe["$session_id"] as? String == session)
        #expect(safe["role"] as? String == "therapist")
        for key in ["$device_name","patient_id","email","note","$set","unexpected","$exception_list"] {#expect(safe[key]==nil)}
        #expect(safe["$geoip_disable"] as? Bool == true);#expect(safe["$process_person_profile"] as? Bool == false)
        #expect(PostHogPrivacyGuard.filter(name:"$screen",properties:raw)==nil)
        #expect(PostHogPrivacyGuard.filter(name:"cbtipul_access_failed",properties:raw)?["$session_id"] as? String == session)
        #expect(PostHogPrivacyGuard.filter(name:"cbtipul_access_failed",properties:["flow":"access","stage":"failed","safe_error_code":"clinical raw error"])!["safe_error_code"]==nil)
    }
}
