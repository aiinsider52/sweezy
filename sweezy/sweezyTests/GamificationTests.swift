import XCTest
@testable import sweezy

@MainActor
final class GamificationTests: XCTestCase {
    func testXPIncreaseOnGuideRead() throws {
        let bus = EventBus.shared
        let service = GamificationService(bus: bus)
        let initial = service.totalXP
        bus.emit(GamEvent(type: .guideReadCompleted, metadata: ["entityId": UUID().uuidString]))
        // allow async main queue
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertGreaterThan(service.totalXP, initial, "XP should increase after guide read")
    }
    
    func testIdempotency() throws {
        let bus = EventBus.shared
        let service = GamificationService(bus: bus)
        let key = UUID().uuidString
        let initial = service.totalXP
        bus.emit(GamEvent(type: .guideReadCompleted, idempotencyKey: "test:\(key)"))
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        let afterFirst = service.totalXP
        bus.emit(GamEvent(type: .guideReadCompleted, idempotencyKey: "test:\(key)"))
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(service.totalXP, afterFirst, "Repeated idempotent event must not increase XP")
        XCTAssertGreaterThan(afterFirst, initial)
    }
}


