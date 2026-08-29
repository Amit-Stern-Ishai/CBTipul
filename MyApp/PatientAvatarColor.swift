import SwiftUI

/// Stable per-patient avatar color, derived deterministically from the
/// patient's database ID so the same patient shows the same color on every
/// screen and across launches. Nothing is stored: the ID is hashed straight
/// into the palette, and names play no part.
enum PatientAvatarColor {

    /// The avatar palette (0xRRGGBB), shared by every screen.
    private static let palette: [UInt32] = [
        0xF2C94C, 0xF2994A, 0xEB5757, 0xE05D8B, 0xBB6BD9,
        0x9B7BFF, 0x6C63FF, 0x4C9AFF, 0x2D9CDB, 0x00C2A8,
        0x6FCF97, 0x27AE60, 0x9CCC65, 0xB2B85C, 0xD4A72C,
        0xCA7842, 0xC86F4A, 0xA94442, 0x8E44AD, 0x5F3DC4,
        0x4B6CB7, 0x3D8EA5, 0x38B2AC, 0x7BA57A, 0xC9A66B,
        0xD7A5A5, 0x8D99AE, 0x6B7280, 0x4B5563, 0x9CA3AF,
    ]

    /// The circle color for a patient's initials avatar.
    static func background(for id: DatabaseID) -> Color {
        Color(uiColor: UIColor(hex: palette[paletteIndex(for: id)]))
    }

    /// Black or white initials, whichever contrasts better with the
    /// patient's background color (WCAG relative luminance).
    static func foreground(for id: DatabaseID) -> Color {
        luminance(of: palette[paletteIndex(for: id)]) > 0.179 ? .black : .white
    }

    /// Maps the ID onto a palette slot with FNV-1a — a deterministic hash,
    /// unlike `hashValue`, which is seeded differently on every launch.
    private static func paletteIndex(for id: DatabaseID) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in id.queryValue.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return Int(hash % UInt64(palette.count))
    }

    /// WCAG relative luminance of an sRGB 0xRRGGBB color.
    private static func luminance(of hex: UInt32) -> Double {
        func linear(_ channel: UInt32) -> Double {
            let value = Double(channel & 0xFF) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(hex >> 16) + 0.7152 * linear(hex >> 8) + 0.0722 * linear(hex)
    }
}
