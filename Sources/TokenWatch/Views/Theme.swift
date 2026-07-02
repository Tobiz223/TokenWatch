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

/// The "Running Meter" palette — a dark cockpit with a warm money accent.
enum Theme {
    static let ink     = Color(hex: 0x0B1220)
    static let slate   = Color(hex: 0x131E33)
    static let slate2  = Color(hex: 0x1B2942)
    static let hair    = Color(hex: 0x26344F)
    static let amber   = Color(hex: 0xF5A623)
    static let amberDk = Color(hex: 0xC97E12)
    static let mint    = Color(hex: 0x4ED6A9)
    static let coral   = Color(hex: 0xFF6B5B)
    static let text    = Color(hex: 0xEAF0FA)
    static let muted   = Color(hex: 0x7C8AA5)
    static let track   = Color(hex: 0x0C1428)
    static let paper   = Color(hex: 0xECE9E1)
    static let paperInk = Color(hex: 0x1A1D22)

    /// Bar gradient for a model family (expensive → cheap encodes cost tier).
    static func barGradient(for short: String) -> LinearGradient {
        let stops: [Color]
        switch short {
        case "Opus":   stops = [Color(hex: 0xA83B30), coral]
        case "Sonnet": stops = [amberDk, amber]
        case "Haiku":  stops = [Color(hex: 0x2F9E7A), mint]
        default:       stops = [amberDk, amber]
        }
        return LinearGradient(colors: stops, startPoint: .leading, endPoint: .trailing)
    }
}

func usd(_ v: Double) -> String { String(format: "$%.2f", v) }

/// Uppercase mono label used as a section eyebrow.
struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(2.2)
            .foregroundColor(Theme.muted)
    }
}
