import Foundation
import Testing
import Supabase
@testable import CBTipul

@MainActor struct PatientActivitiesTransportTests {
    @Test func authenticatedPostUsesEmptyObjectAndReadOnlyRPC() async throws {
        ActivitiesHTTP.requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ActivitiesHTTP.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://activities-test.invalid")!, supabaseKey: "synthetic",
            options: .init(auth: .init(storage: ClinicalTestAuthStorage(), autoRefreshToken: false), global: .init(session: URLSession(configuration: configuration))))
        _ = try await client.auth.signIn(email: "synthetic@example.invalid", password: "unused")
        let service = PatientAssignmentService(client: client)
        #expect(try await service.requestActivities(send: false) == "no_request")
        #expect(try await service.requestActivities(send: true) == "pending")
        let requests = ActivitiesHTTP.requests
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.httpMethod == "POST" && $0.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true })
        #expect(requests[0].url?.path == "/rest/v1/rpc/request_patient_activities")
        #expect(requests[1].url?.path == "/functions/v1/request-patient-activities")
        let read = try JSONSerialization.jsonObject(with: requests[0].httpBody!) as! [String: Bool]
        let send = try JSONSerialization.jsonObject(with: requests[1].httpBody!) as! [String: String]
        #expect(read == ["p_send": false])
        #expect(send.isEmpty)
    }
}
private final class ActivitiesHTTP: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let body: String
        if request.url!.path.hasSuffix("/token") {
            body = """
            {"access_token":"synthetic","refresh_token":"synthetic","token_type":"bearer","expires_in":3600,"expires_at":4102444800,"user":{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","aud":"authenticated","email":"synthetic@example.invalid","email_confirmed_at":"2026-01-01T00:00:00Z","app_metadata":{},"user_metadata":{},"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}}
            """
        } else {
            var copy = request
            if copy.httpBody == nil, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var bytes = [UInt8](repeating: 0, count: 1024); var data = Data()
                while stream.hasBytesAvailable { let count = stream.read(&bytes, maxLength: bytes.count); if count <= 0 { break }; data.append(bytes, count: count) }
                copy.httpBody = data
            }
            Self.requests.append(copy)
            body = request.url!.path.contains("/rpc/") ? "\"no_request\"" : "{\"status\":\"pending\"}"
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
