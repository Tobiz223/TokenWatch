import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: alpha)
    }
}

/// A restrained, professional dark palette — one accent (money), quiet everything else.
enum Theme {
    static let bg       = Color(hex: 0x0A0F1A)
    static let surface  = Color(hex: 0x111826)
    static let surface2 = Color(hex: 0x161F30)
    static let line     = Color(hex: 0x212C42)
    static let lineSoft = Color(hex: 0x1A2334)
    static let accent   = Color(hex: 0xE8A317)
    static let green    = Color(hex: 0x3FB98C)   // haiku / cheap
    static let amber    = Color(hex: 0xE8A317)   // sonnet / mid
    static let red      = Color(hex: 0xE5564B)   // opus / overkill
    static let text     = Color(hex: 0xE6EDF7)
    static let muted    = Color(hex: 0x8494AC)
    static let faint    = Color(hex: 0x5A6B85)
    static let track    = Color(hex: 0x0E1524)

    /// Flat family color (expensive → cheap encodes cost tier).
    static func familyColor(_ short: String) -> Color {
        switch short {
        case "Opus":   return red
        case "Sonnet": return amber
        case "Haiku":  return green
        default:       return amber
        }
    }
}

/// Uppercase section label with a trailing hairline rule.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(spacing: 10) {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.6)
                .foregroundColor(Theme.faint)
            Rectangle().fill(Theme.lineSoft).frame(height: 1)
        }
    }
}
