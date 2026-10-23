import SwiftUI
import ScrollCore

private let ink = Color(red: 0.13, green: 0.19, blue: 0.20)
private let teal = Color(red: 0.12, green: 0.43, blue: 0.39)
private let paper = Color(red: 0.96, green: 0.96, blue: 0.94)

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            status
            HStack(spacing: 16) {
                deviceCard(title: model.text("Mouse", "마우스"), english: "MOUSE", symbol: "computermouse", natural: $model.mouseNatural,
                           active: model.lastKind == .mouse, caption: model.text("A familiar turn of the wheel.", "휠은 익숙한 방향으로."))
                deviceCard(title: model.text("Trackpad", "트랙패드"), english: "TRACKPAD", symbol: "rectangle.and.hand.point.up.left", natural: $model.trackpadNatural,
                           active: model.lastKind == .trackpad, caption: model.text("Follow your fingertips.", "손끝을 따라 자연스럽게."))
            }
            testArea
            footer
        }
        .padding(30)
        .frame(width: 740)
        .background(paper)
        .foregroundStyle(ink)
        .tint(teal)
        .preferredColorScheme(.light)
        .environment(\.locale, Locale(identifier: model.language.rawValue))
        .alert(model.text("Settings", "설정 안내"), isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            if model.isPermissionHelp {
                Button(model.text("Open Settings", "시스템 설정 열기")) { model.openAccessibility() }
                Button(model.text("Show App", "앱 위치 보기")) { model.revealApp() }
            }
            Button(model.text("OK", "확인")) { model.message = nil }
        } message: { Text(model.alertMessage) }
    }

    private var header: some View {
        HStack(alignment: .center) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(teal).frame(width: 56, height: 56)
                Image(systemName: "arrow.up.arrow.down").font(.system(size: 25, weight: .medium)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("ScrollSplit").font(.system(size: 27, weight: .semibold, design: .rounded))
                Text(model.text("Two devices. Two scroll directions.", "두 기기, 각자의 스크롤.")).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Toggle(model.text("Split scrolling", "스크롤 분리"), isOn: $model.enabled).toggleStyle(.switch).font(.system(size: 12, weight: .medium))
                Text("SCROLL YOUR WAY").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.5).foregroundStyle(.secondary)
            }
        }
    }

    private var status: some View {
        HStack(spacing: 12) {
            Image(systemName: model.running ? "checkmark.circle.fill" : model.enabled ? "lock.circle" : "pause.circle")
                .font(.system(size: 23)).foregroundStyle(model.running ? teal : Color.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.statusTitle).font(.system(size: 13, weight: .semibold))
                Text(model.statusDetail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            if !model.trusted {
                VStack(spacing: 6) {
                    Button(model.text("Allow Access", "권한 허용하기")) { model.requestPermission() }
                        .buttonStyle(.borderedProminent).controlSize(.regular)
                    Button(model.text("Already allowed?", "이미 허용했는데 안 되나요?")) { model.message = .accessibilityHelp }
                        .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(teal)
                }
            } else if model.enabled && !model.running {
                Button(model.text("Check Access", "권한 확인")) { model.openAccessibility() }.buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(model.running ? teal.opacity(0.07) : Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }

    private func deviceCard(title: String, english: String, symbol: String, natural: Binding<Bool>, active: Bool, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Text(english).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(.secondary)
                Spacer()
                Circle().fill(active && model.running ? teal : Color.gray.opacity(0.2)).frame(width: 6, height: 6)
                    .accessibilityLabel(active && model.running ? model.text("Last active device", "최근 입력 기기") : model.text("Waiting for input", "입력 대기"))
            }
            HStack(spacing: 18) {
                Image(systemName: symbol).font(.system(size: 39, weight: .ultraLight)).frame(width: 54, height: 56).foregroundStyle(teal)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: 22, weight: .semibold))
                    Text(caption).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Rectangle().fill(ink.opacity(0.08)).frame(height: 1)
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.text("Natural scrolling", "자연스러운 스크롤")).font(.system(size: 12, weight: .medium))
                    Text(natural.wrappedValue ? model.text("On · Content follows your gesture", "켬 · 콘텐츠가 움직임을 따라가요") : model.text("Off · Traditional scroll direction", "끔 · 전통적인 스크롤 방향이에요"))
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Toggle("\(title) \(model.text("natural scrolling", "자연스러운 스크롤"))", isOn: natural).labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(ink.opacity(0.07)))
    }

    private var testArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(model.text("Give it a scroll", "직접 스크롤해 보세요")).font(.system(size: 13, weight: .semibold))
                Spacer()
                Label(model.lastDevice, systemImage: model.lastKind == .mouse ? "computermouse" : model.lastKind == .trackpad ? "hand.draw" : "dot.radiowaves.left.and.right")
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<10) { index in
                        HStack(alignment: .top, spacing: 20) {
                            Text(String(format: "%02d", index + 1)).font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(teal.opacity(0.6)).frame(width: 27)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(testCopy[index].0).font(.system(size: 17, weight: .medium))
                                Text(testCopy[index].1).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(5)
                            }
                            Spacer()
                            Image(systemName: "arrow.down").font(.system(size: 14)).foregroundStyle(teal.opacity(0.4))
                        }
                        .padding(22)
                        if index < 9 { Divider().padding(.horizontal, 22) }
                    }
                }
            }
            .frame(height: 165)
            .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(ink.opacity(0.08)))
            HStack {
                Text(model.detectionHint).font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Text(model.text("\(model.count) events", "입력 \(model.count)회")).font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 16) {
            Divider()
            HStack {
                Picker("Language / 언어", selection: $model.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.label).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 145)
                .accessibilityLabel("Language / 언어")
                Spacer()
                Toggle(model.text("Launch at login", "로그인 시 실행"), isOn: Binding(get: { model.launchAtLogin }, set: model.setLogin)).toggleStyle(.checkbox).font(.system(size: 11))
                Spacer()
                Button(model.text("Use recommended", "추천 설정으로")) { model.applyRecommended() }.buttonStyle(.plain).foregroundStyle(teal).font(.system(size: 11, weight: .medium))
                Text("·").foregroundStyle(.tertiary)
                Button(model.text("Quit", "종료")) { NSApp.terminate(nil) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Text(model.text("Keep your macOS settings. ScrollSplit handles each device while it runs.", "macOS 설정은 그대로 두세요. ScrollSplit이 실행 중일 때 기기별 방향을 맞춥니다."))
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private var testCopy: [(String, String)] { [
        (model.text("The best direction feels familiar.", "익숙한 방향이 가장 좋은 방향."),
         model.text("Roll your mouse wheel down. If the next paragraph appears, you’re on the right track.", "마우스 휠을 아래로 굴려 보세요. 다음 문장이 보이면 잘 작동하고 있어요.")),
        (model.text("Now, try your trackpad.", "이제, 트랙패드로 바꿔 보세요."),
         model.text("Slide two fingers up. With natural scrolling on, the document follows your fingertips.", "두 손가락을 위로 밀면 문서도 위로 움직여요. 손끝과 콘텐츠가 같은 방향입니다.")),
        (model.text("Switch devices. Keep your flow.", "바꿔 잡아도, 바로 자연스럽게."),
         model.text("Move between your mouse and trackpad without changing settings each time.", "마우스와 트랙패드를 번갈아 사용해도 설정을 다시 바꿀 필요가 없어요.")),
        (model.text("Small change. Everyday comfort.", "작은 차이가 만드는 편안함."),
         model.text("Use the switches above to choose natural scrolling for each device independently.", "위의 스위치로 각 기기의 자연스러운 스크롤을 따로 바꿀 수 있어요.")),
        (model.text("Close the window. Keep scrolling.", "창을 닫아도 괜찮아요."),
         model.text("The arrows in your menu bar bring you back here whenever you need them.", "메뉴 막대의 위아래 화살표를 누르면 언제든 이 화면을 다시 열 수 있어요.")),
        (model.text("Need a pause?", "잠깐 멈추고 싶다면."),
         model.text("Turn off Split scrolling to go straight back to your macOS scroll settings.", "스크롤 분리 스위치를 끄세요. 즉시 macOS의 기본 방향으로 돌아갑니다.")),
        (model.text("Sideways, too.", "가로 스크롤도 함께."),
         model.text("The same direction settings apply to horizontal wheels and Shift + scroll.", "가로 휠과 Shift + 휠에도 같은 방향 설정이 적용됩니다.")),
        (model.text("Your input stays on your Mac.", "입력은 이 Mac 안에서만."),
         model.text("Only scroll direction is processed. No keyboard monitoring or data sent elsewhere.", "스크롤 방향만 처리해요. 키보드 입력을 수집하거나 외부로 전송하지 않아요.")),
        (model.text("A pairing that feels right.", "나에게 맞는 조합으로."),
         model.text("Our recommended setup: natural scrolling off for your mouse and on for your trackpad.", "추천 설정은 마우스의 자연스러운 스크롤 끔, 트랙패드의 자연스러운 스크롤 켬입니다.")),
        (model.text("You’re all set.", "준비됐어요."),
         model.text("Try scrolling in your everyday apps and see how both devices feel.", "이제 평소 사용하던 앱에서도 스크롤 방향을 확인해 보세요."))
    ] }
}
