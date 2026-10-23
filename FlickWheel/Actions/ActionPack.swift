import Foundation

// a named bundle of actions the user can switch on in Settings; none are on by default
struct ActionPack: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let description: String?
    let actions: [WheelAction]
    let bundled: Bool
}
