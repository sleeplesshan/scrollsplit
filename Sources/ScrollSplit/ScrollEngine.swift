import AppKit
import ApplicationServices
import ScrollCore

final class ScrollEngine {
    var policy = ScrollPolicy()
    private(set) var lastReading: DeviceReading?
    private(set) var eventCount = 0
    private(set) var reversedCount = 0
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let resolver = DeviceResolver()
    var running: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func start() -> Bool {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true); return running }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let engine = Unmanaged<ScrollEngine>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if engine.policy.enabled, let tap = engine.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard type == .scrollWheel, engine.policy.enabled else { return Unmanaged.passUnretained(event) }
            return autoreleasepool {
                let reading = engine.resolver.identify(event)
                engine.lastReading = reading
                engine.eventCount += 1
                if let appEvent = NSEvent(cgEvent: event),
                   engine.policy.shouldReverse(device: reading.device, systemNatural: appEvent.isDirectionInvertedFromDevice) {
                    engine.resolver.reverse(event)
                    engine.reversedCount += 1
                }
                return Unmanaged.passUnretained(event)
            }
        }
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(1) << CGEventType.scrollWheel.rawValue,
            callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        guard let runSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            CFMachPortInvalidate(port)
            return false
        }
        tap = port
        source = runSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return running
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
        resolver.reset()
    }

    deinit { stop() }
}
