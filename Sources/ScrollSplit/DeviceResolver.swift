import AppKit
import IOKit
import ScrollCore
import Darwin

struct DeviceReading {
    var device: ScrollDevice
    // Hardware-reported names stay unchanged; nil is localized by the UI.
    var name: String?
    var exact: Bool
}

/// Optional HID sender lookup. These runtime symbols are not public SDK API;
/// absence is supported and falls back conservatively to public event fields.
final class DeviceResolver {
    private typealias CopyHID = @convention(c) (CGEvent) -> Unmanaged<CFTypeRef>?
    private typealias SenderID = @convention(c) (CFTypeRef) -> UInt64
    private typealias GetFloat = @convention(c) (CFTypeRef, UInt32) -> Double
    private typealias SetFloat = @convention(c) (CFTypeRef, UInt32, Double) -> Void
    private let copyHID: CopyHID?
    private let senderID: SenderID?
    private let getFloat: GetFloat?
    private let setFloat: SetFloat?
    private var cache: [UInt64: DeviceReading] = [:]
    private var failed: [UInt64: TimeInterval] = [:]

    init() {
        let handle = dlopen(nil, RTLD_LAZY)
        copyHID = dlsym(handle, "CGEventCopyIOHIDEvent").map { unsafeBitCast($0, to: CopyHID.self) }
        senderID = dlsym(handle, "IOHIDEventGetSenderID").map { unsafeBitCast($0, to: SenderID.self) }
        getFloat = dlsym(handle, "IOHIDEventGetFloatValue").map { unsafeBitCast($0, to: GetFloat.self) }
        setFloat = dlsym(handle, "IOHIDEventSetFloatValue").map { unsafeBitCast($0, to: SetFloat.self) }
    }

    func reset() { cache.removeAll(); failed.removeAll() }

    func reverse(_ event: CGEvent) {
        // WebKit and other consumers also read the underlying HID scroll values.
        // Keep them consistent with Quartz, preserving fractional acceleration.
        guard let copyHID, let getFloat, let setFloat, let hid = copyHID(event)?.takeRetainedValue() else {
            ScrollPolicy.reverse(event)
            return
        }
        let xField: UInt32 = 6 << 16
        let yField = xField | 1
        let x = getFloat(hid, xField)
        let y = getFloat(hid, yField)
        ScrollPolicy.reverse(event)
        setFloat(hid, xField, -x)
        setFloat(hid, yField, -y)
    }

    func identify(_ event: CGEvent) -> DeviceReading {
        if let copyHID, let senderID, let hid = copyHID(event)?.takeRetainedValue() {
            let id = senderID(hid)
            if id != 0 {
                if let saved = cache[id] { return saved }
                let now = ProcessInfo.processInfo.systemUptime
                if now - (failed[id] ?? -10) > 2 {
                    if let reading = registryDevice(id) {
                        if cache.count > 128 { cache.removeAll() }
                        cache[id] = reading
                        return reading
                    }
                    if failed.count > 128 { failed.removeAll() }
                    failed[id] = now
                }
            }
        }
        let device = ScrollPolicy.fallbackDevice(
            continuous: event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0,
            phase: event.getIntegerValueField(.scrollWheelEventScrollPhase),
            momentum: event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        )
        return DeviceReading(device: device, name: nil, exact: false)
    }

    private func registryDevice(_ id: UInt64) -> DeviceReading? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IORegistryEntryIDMatching(id))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var node = service
        var ancestors: [io_registry_entry_t] = []
        defer { ancestors.forEach { IOObjectRelease($0) } }
        var product: String?
        var isTrackpad = false
        var isMouse = false
        for _ in 0..<4 {
            func property(_ key: String) -> Any? {
                IORegistryEntryCreateCFProperty(node, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            }
            let name = property("Product") as? String
            if product == nil { product = name }
            let acceleration = property("HIDScrollAccelerationType") as? String
            if acceleration == "HIDTrackpadScrollAcceleration"
                || IOObjectConformsTo(node, "AppleMultitouchTrackpadHIDEventDriver") != 0
                || name?.localizedCaseInsensitiveContains("trackpad") == true {
                isTrackpad = true
            }
            if acceleration == "HIDMouseScrollAcceleration"
                || name?.localizedCaseInsensitiveContains("mouse") == true
                || ((property("PrimaryUsagePage") as? NSNumber)?.intValue == 1
                    && (property("PrimaryUsage") as? NSNumber)?.intValue == 2) {
                isMouse = true
            }
            var parent: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(node, kIOServicePlane, &parent) == KERN_SUCCESS else { break }
            ancestors.append(parent)
            node = parent
        }
        guard isTrackpad || isMouse else { return nil }
        return DeviceReading(device: isTrackpad ? .trackpad : .mouse,
                             name: product, exact: true)
    }
}
