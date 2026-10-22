enum Backdrop: Equatable {
    case gradient(Int)
    case solid(RGB)
    case image

    static let gradients: [[RGB]] = [
        [RGB(hex: 0xFF6B6B), RGB(hex: 0xFFA64D), RGB(hex: 0xFFD93D)],
        [RGB(hex: 0x3A7BD5), RGB(hex: 0x00D2FF)],
        [RGB(hex: 0x43E97B), RGB(hex: 0x38F9D7)],
        [RGB(hex: 0xFF9A9E), RGB(hex: 0xFECFEF)],
        [RGB(hex: 0xA18CD1), RGB(hex: 0xFBC2EB)],
        [RGB(hex: 0x0F2027), RGB(hex: 0x2C5364), RGB(hex: 0x6DD5ED)],
        [RGB(hex: 0x2193B0), RGB(hex: 0x6DD5ED)],
        [RGB(hex: 0xF093FB), RGB(hex: 0xF5576C)],
        [RGB(hex: 0x4E54C8), RGB(hex: 0x8F94FB)],
    ]

    static let solids: [RGB] = [
        RGB(hex: 0xFFFFFF), RGB(hex: 0xF2C94C), RGB(hex: 0xA5CF4D),
        RGB(hex: 0x4BA871), RGB(hex: 0x2E9C93), RGB(hex: 0x56C9DB),
        RGB(hex: 0x3B6BD6), RGB(hex: 0x233047), RGB(hex: 0x7E57C2),
    ]
}

extension RGB {
    init(hex: UInt32) {
        self.init(r: Double((hex >> 16) & 0xFF) / 255, g: Double((hex >> 8) & 0xFF) / 255, b: Double(hex & 0xFF) / 255)
    }
}
