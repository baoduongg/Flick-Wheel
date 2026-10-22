import CoreGraphics

enum BackgroundRatio: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case square = "1:1"
    case wide = "16:9"
    case portrait = "4:5"

    var id: String { rawValue }

    var value: CGFloat? {
        switch self {
        case .auto: return nil
        case .square: return 1
        case .wide: return 16.0 / 9.0
        case .portrait: return 4.0 / 5.0
        }
    }
}
