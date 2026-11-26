import Foundation

/// A local account record is not proof of an unexpired Apple session.
enum BloomBoxAccountPolicy {
    enum Presence: Equatable { case present, absent, unknown }
    enum State: Equatable { case unavailable, notLinked, incomplete, saved, unknown }
    static func state(available: Bool, email: Presence, token: Presence, adsid: Presence) -> State {
        guard available else { return .unavailable }
        if [email, token, adsid].contains(.unknown) { return .unknown }
        if email == .present && token == .present && adsid == .present { return .saved }
        if [email, token, adsid].contains(.present) { return .incomplete }
        return .notLinked
    }
    static func initialAccountPage(_ state: State) -> Int {
        state == .saved || state == .unavailable ? 3 : 2
    }
    static let requestKey = "BloomBoxNativeAccountRequestV1"
    static let resumeKey = "BloomBoxWizardAccountCheckpointV1"
    static func request(mode: String, now: Date = Date()) -> [String: Any] {
        ["id": UUID().uuidString, "mode": mode, "expires": now.addingTimeInterval(120)]
    }
}
