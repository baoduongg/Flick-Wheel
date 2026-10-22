import CoreGraphics

enum CropRatio: String, CaseIterable, Identifiable {
    case free = "Free"
    case square = "1:1"
    case wide = "16:9"
    case tall = "9:16"
    case landscape = "4:3"
    case portrait = "3:4"

    var id: String { rawValue }

    var value: CGFloat? {
        switch self {
        case .free: return nil
        case .square: return 1
        case .wide: return 16.0 / 9.0
        case .tall: return 9.0 / 16.0
        case .landscape: return 4.0 / 3.0
        case .portrait: return 3.0 / 4.0
        }
    }
}
