import XCTest
@testable import CBTipul
@MainActor final class SilentContextRefreshTests: XCTestCase {
 func testSameAccountFailureKeepsRouteButBlocksWrites() async throws {
  var fails = false
  var identity: String? = "first"
  let context = AppContext(version: 1, role: .therapist, activation: nil, patientId: nil, entitlement: AppEntitlement(access: .full))
  let service = AppContextService(identity: { identity }, request: { if fails { throw URLError(.notConnectedToInternet) }; return context })
  _ = try await service.getCurrentAppContext()
  XCTAssertEqual(service.current, context)
  fails = true
  do { _ = try await service.getCurrentAppContext(); XCTFail() } catch {}
  XCTAssertEqual(service.current, context)
  XCTAssertFalse(EntitlementState.shared.canWrite)
  XCTAssertNotNil(service.loadError)
  fails = false
  _ = try await service.getCurrentAppContext()
  XCTAssertTrue(EntitlementState.shared.canWrite)
  identity = "second"
  XCTAssertNil(service.current)
  service.clear()
  XCTAssertNil(service.current)
  XCTAssertFalse(EntitlementState.shared.canWrite)
 }
}
