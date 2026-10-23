import XCTest
import CoreGraphics
@testable import ScrollCore

final class ScrollPolicyTests: XCTestCase {
    func testAllDirectionCombinations() {
        for mouse in [false, true] {
            for trackpad in [false, true] {
                for system in [false, true] {
                    var policy = ScrollPolicy()
                    policy.mouseNatural = mouse
                    policy.trackpadNatural = trackpad
                    XCTAssertEqual(policy.shouldReverse(device: .mouse, systemNatural: system), mouse != system)
                    XCTAssertEqual(policy.shouldReverse(device: .trackpad, systemNatural: system), trackpad != system)
                    XCTAssertFalse(policy.shouldReverse(device: .unknown, systemNatural: system))
                    policy.enabled = false
                    XCTAssertFalse(policy.shouldReverse(device: .mouse, systemNatural: system))
                    XCTAssertFalse(policy.shouldReverse(device: .trackpad, systemNatural: system))
                }
            }
        }
    }

    func testRecommendedWithEitherSystemSetting() {
        let policy = ScrollPolicy()
        XCTAssertTrue(policy.shouldReverse(device: .mouse, systemNatural: true))
        XCTAssertFalse(policy.shouldReverse(device: .trackpad, systemNatural: true))
        XCTAssertFalse(policy.shouldReverse(device: .mouse, systemNatural: false))
        XCTAssertTrue(policy.shouldReverse(device: .trackpad, systemNatural: false))
    }

    func testConservativeFallbackAndMomentum() {
        XCTAssertEqual(ScrollPolicy.fallbackDevice(continuous: false, phase: 0, momentum: 0), .mouse)
        XCTAssertEqual(ScrollPolicy.fallbackDevice(continuous: true, phase: 1, momentum: 0), .trackpad)
        XCTAssertEqual(ScrollPolicy.fallbackDevice(continuous: true, phase: 0, momentum: 2), .trackpad)
        XCTAssertEqual(ScrollPolicy.fallbackDevice(continuous: true, phase: 0, momentum: 0), .unknown)
    }

    func testReversalPreservesPrecisionAndMetadata() throws {
        let event = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 4, wheel2: -7, wheel3: 0))
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 3)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -2)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0.375)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -0.625)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 5)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -9)
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 2)
        event.flags = [.maskShift]
        let intFields: [CGEventField] = [.scrollWheelEventDeltaAxis1, .scrollWheelEventDeltaAxis2, .scrollWheelEventPointDeltaAxis1, .scrollWheelEventPointDeltaAxis2]
        let doubleFields: [CGEventField] = [.scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis2]
        let ints = intFields.map { event.getIntegerValueField($0) }
        let doubles = doubleFields.map { event.getDoubleValueField($0) }
        ScrollPolicy.reverse(event)
        for (field, value) in zip(intFields, ints) { XCTAssertEqual(event.getIntegerValueField(field), -value) }
        for (field, value) in zip(doubleFields, doubles) { XCTAssertEqual(event.getDoubleValueField(field), -value, accuracy: 0.0001) }
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventMomentumPhase), 2)
        XCTAssertEqual(event.flags, [.maskShift])
        ScrollPolicy.reverse(event)
        for (field, value) in zip(intFields, ints) { XCTAssertEqual(event.getIntegerValueField(field), value) }
    }
}
