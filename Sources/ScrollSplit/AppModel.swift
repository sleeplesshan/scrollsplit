import AppKit
import ApplicationServices
import Combine
import ServiceManagement
import ScrollCore

final class AppModel: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: "appLanguage")
            statusChanged?()
        }
    }
    @Published var enabled: Bool { didSet { save(); reconcile() } }
    @Published var mouseNatural: Bool { didSet { save() } }
    @Published var trackpadNatural: Bool { didSet { save() } }
    @Published private(set) var trusted = false
    @Published private(set) var running = false
    @Published private var lastReading: DeviceReading?
    @Published private(set) var count = 0
    @Published private(set) var launchAtLogin = false
    enum Message {
        case accessibilityHelp
        case loginApproval
        case loginFailure(String)
    }
    @Published var message: Message?
    private let defaults = UserDefaults.standard
    private let engine = ScrollEngine()
    private var timer: Timer?
    private var permissionTicks = 0
    private var observers: [NSObjectProtocol] = []
    var statusChanged: (() -> Void)?

    init() {
        defaults.register(defaults: ["enabled": true, "mouseNatural": false, "trackpadNatural": true])
        language = AppLanguage(savedValue: defaults.string(forKey: "appLanguage"))
        enabled = defaults.bool(forKey: "enabled")
        mouseNatural = defaults.bool(forKey: "mouseNatural")
        trackpadNatural = defaults.bool(forKey: "trackpadNatural")
        save()
        reconcile()
        refreshLogin()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.engine.stop()
            self?.reconcile()
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reconcile()
            self?.refreshLogin()
        })
    }

    func text(_ english: String, _ korean: String) -> String {
        language.text(english, korean)
    }

    var lastKind: ScrollDevice { lastReading?.device ?? .unknown }

    var lastDevice: String {
        guard let reading = lastReading else { return text("Waiting for scroll input", "스크롤 입력 대기 중") }
        if let name = reading.name { return name }
        switch reading.device {
        case .mouse: return reading.exact ? text("Mouse", "마우스") : text("Scroll-wheel mouse", "휠 마우스")
        case .trackpad: return reading.exact ? text("Trackpad", "트랙패드") : text("Trackpad gesture", "트랙패드 제스처")
        case .unknown: return text("Unidentified continuous scroll", "확인되지 않은 연속 스크롤")
        }
    }

    var detectionHint: String {
        guard let reading = lastReading else {
            return text("Try scrolling the document with either device.", "마우스나 트랙패드로 아래 문서를 스크롤해 보세요.")
        }
        if reading.exact { return text("Input device identified directly.", "입력 기기를 직접 확인했습니다.") }
        return reading.device == .unknown
            ? text("Device unknown. Keeping the original direction.", "이 입력은 기기를 구분할 수 없어 방향을 유지합니다.")
            : text("Device inferred from scroll event properties.", "스크롤 이벤트 특성으로 기기를 추정했습니다.")
    }

    var alertMessage: String {
        switch message {
        case .accessibilityHelp:
            return text(
                "If ScrollSplit is already enabled but still asks for access, macOS may be remembering an older build. In Accessibility, select ScrollSplit and remove it with −, then use + to add the current app and enable it. Quit and reopen ScrollSplit afterward. Use Show App to locate this copy.\n\nApp: ",
                "이미 허용했는데도 작동하지 않으면 macOS에 이전 빌드의 권한이 남아 있을 수 있습니다. 손쉬운 사용에서 ScrollSplit을 선택하고 −로 제거한 뒤, +로 현재 앱을 다시 추가하고 허용하세요. 이후 앱을 종료하고 다시 실행하세요. ‘앱 위치 보기’로 현재 실행 중인 앱을 찾을 수 있습니다.\n\n앱: "
            ) + Bundle.main.bundlePath
        case .loginApproval:
            return text("Allow ScrollSplit in System Settings → General → Login Items.", "시스템 설정 → 일반 → 로그인 항목에서 ScrollSplit을 허용해 주세요.")
        case .loginFailure(let detail):
            return text("Could not update launch at login: ", "로그인 시 실행을 변경하지 못했습니다: ") + detail
        case nil: return ""
        }
    }

    var isPermissionHelp: Bool {
        if case .accessibilityHelp? = message { return true }
        return false
    }

    func revealApp() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    var statusTitle: String {
        !enabled ? text("Paused", "일시 정지됨") :
        !trusted ? text("One quick permission to get started", "권한 설정이 필요해요") :
        running ? text("Each device, scrolling your way", "각 기기에 맞게 적용 중") :
        text("Check the scroll connection", "스크롤 연결을 확인해 주세요")
    }

    var statusDetail: String {
        !enabled ? text("Using your macOS scroll settings for now.", "현재는 macOS의 스크롤 설정을 그대로 사용합니다.") :
        !trusted ? text("Allow ScrollSplit in Accessibility to start.", "손쉬운 사용에서 ScrollSplit을 허용하면 바로 시작됩니다.") :
        running ? text("Close this window anytime. ScrollSplit stays in the menu bar.", "창을 닫아도 메뉴 막대에서 계속 실행됩니다.") :
        text("Check Accessibility permission or reopen the app.", "권한을 다시 확인하거나 앱을 다시 실행해 주세요.")
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openAccessibility()
        reconcile()
    }

    func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func setLogin(_ requested: Bool) {
        do {
            if requested { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshLogin()
            if SMAppService.mainApp.status == .requiresApproval {
                message = .loginApproval
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            message = .loginFailure(error.localizedDescription)
            refreshLogin()
        }
    }

    func applyRecommended() {
        mouseNatural = false
        trackpadNatural = true
        enabled = true
    }

    func shutdown() { engine.stop() }

    private func save() {
        defaults.set(enabled, forKey: "enabled")
        defaults.set(mouseNatural, forKey: "mouseNatural")
        defaults.set(trackpadNatural, forKey: "trackpadNatural")
        engine.policy.enabled = enabled
        engine.policy.mouseNatural = mouseNatural
        engine.policy.trackpadNatural = trackpadNatural
        statusChanged?()
    }

    private func reconcile() {
        let permission = AXIsProcessTrusted()
        if trusted != permission { trusted = permission }
        if enabled && permission {
            let started = engine.start()
            if running != started { running = started }
        } else {
            engine.stop()
            if running { running = false }
        }
        statusChanged?()
    }

    private func refreshLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func tick() {
        permissionTicks += 1
        if permissionTicks % 8 == 0 { reconcile() }
        if count != engine.eventCount {
            count = engine.eventCount
            lastReading = engine.lastReading
        }
    }
}
