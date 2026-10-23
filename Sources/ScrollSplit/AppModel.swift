import AppKit
import ApplicationServices
import Combine
import ServiceManagement
import ScrollCore

final class AppModel: ObservableObject {
    @Published var enabled: Bool { didSet { save(); reconcile() } }
    @Published var mouseNatural: Bool { didSet { save() } }
    @Published var trackpadNatural: Bool { didSet { save() } }
    @Published private(set) var trusted = false
    @Published private(set) var running = false
    @Published private(set) var lastDevice = "스크롤 입력 대기 중"
    @Published private(set) var lastKind: ScrollDevice = .unknown
    @Published private(set) var detectionHint = "마우스나 트랙패드로 아래 문서를 스크롤해 보세요."
    @Published private(set) var count = 0
    @Published private(set) var launchAtLogin = false
    @Published var message: String?
    private let defaults = UserDefaults.standard
    private let engine = ScrollEngine()
    private var timer: Timer?
    private var permissionTicks = 0
    private var observers: [NSObjectProtocol] = []
    var statusChanged: (() -> Void)?

    init() {
        defaults.register(defaults: ["enabled": true, "mouseNatural": false, "trackpadNatural": true])
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

    var statusTitle: String {
        !enabled ? "일시 정지됨" : !trusted ? "권한 설정이 필요해요" : running ? "각 기기에 맞게 적용 중" : "스크롤 연결을 확인해 주세요"
    }

    var statusDetail: String {
        !enabled ? "현재는 macOS의 스크롤 설정을 그대로 사용합니다." :
        !trusted ? "손쉬운 사용에서 ScrollSplit을 허용하면 바로 시작됩니다." :
        running ? "창을 닫아도 메뉴 막대에서 계속 실행됩니다." :
        "권한을 다시 확인하거나 앱을 다시 실행해 주세요."
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
                message = "시스템 설정 → 일반 → 로그인 항목에서 ScrollSplit을 허용해 주세요."
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            message = "로그인 시 실행을 변경하지 못했습니다: \(error.localizedDescription)"
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
            if let reading = engine.lastReading {
                lastDevice = reading.name
                lastKind = reading.device
                detectionHint = reading.exact ? "입력 기기를 직접 확인했습니다." :
                    reading.device == .unknown ? "이 입력은 기기를 구분할 수 없어 방향을 유지합니다." : "스크롤 이벤트 특성으로 기기를 추정했습니다."
            }
        }
    }
}
