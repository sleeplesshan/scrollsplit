import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case korean = "ko"

    var id: String { rawValue }
    var label: String { self == .english ? "English" : "한국어" }

    /// Use English for first launch and for unrecognized saved values,
    /// independently of the Mac's preferred language.
    init(savedValue: String?) {
        self = savedValue.flatMap(Self.init(rawValue:)) ?? .english
    }

    func text(_ english: String, _ korean: String) -> String {
        self == .english ? english : korean
    }
}
