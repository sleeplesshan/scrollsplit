import CoreGraphics

public enum ScrollDevice: String {
    case mouse, trackpad, unknown
}

public struct ScrollPolicy {
    public var enabled = true
    public var mouseNatural = false
    public var trackpadNatural = true

    public init() {}

    public func shouldReverse(device: ScrollDevice, systemNatural: Bool) -> Bool {
        guard enabled else { return false }
        switch device {
        case .mouse: return mouseNatural != systemNatural
        case .trackpad: return trackpadNatural != systemNatural
        case .unknown: return false
        }
    }

    /// Discrete wheel events are reliable. Continuous events without an identified
    /// sender or gesture phase are ambiguous (e.g. a smooth wheel or Magic Mouse).
    public static func fallbackDevice(continuous: Bool, phase: Int64, momentum: Int64) -> ScrollDevice {
        if !continuous { return .mouse }
        if phase != 0 || momentum != 0 { return .trackpad }
        return .unknown
    }

    public static func reverse(_ event: CGEvent) {
        let fields: [(CGEventField, CGEventField, CGEventField)] = [
            (.scrollWheelEventDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventPointDeltaAxis1),
            (.scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis2)
        ]
        // Capture ALL representations before any write: Quartz can update related
        // fields as a side effect of setting the line delta.
        let values = fields.map { (event.getIntegerValueField($0.0), event.getDoubleValueField($0.1), event.getIntegerValueField($0.2)) }
        for (index, field) in fields.enumerated() {
            let value = values[index]
            event.setIntegerValueField(field.0, value: negate(value.0))
            event.setDoubleValueField(field.1, value: -value.1)
            event.setIntegerValueField(field.2, value: negate(value.2))
        }
    }

    private static func negate(_ value: Int64) -> Int64 {
        value == Int64.min ? Int64.max : -value
    }
}
