import SwiftUI

struct ReceiptView: View {
    @EnvironmentObject var store: UsageStore

    var body: some View {
        VStack(spacing: 0) {
            receiptCard
            tornEdge
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private var receiptCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 3) {
                Text("TOKENWATCH")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .tracking(3)
                Text("USAGE RECEIPT · CLAUDE CODE")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(Color(hex: 0x6B6559))
            }
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) { dashed }

            if store.history.isEmpty {
                Text("No requests found yet.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(hex: 0x8A8478))
                    .padding(.vertical, 26)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.history.prefix(120)) { item in
                            ReceiptRow(item: item)
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
        }
        .padding(16)
        .background(Theme.paper)
        .foregroundColor(Theme.paperInk)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var dashed: some View {
        Rectangle()
            .fill(Color(hex: 0xB9B3A3))
            .frame(height: 1.5)
            .mask {
                HStack(spacing: 4) {
                    ForEach(0..<60, id: \.self) { _ in Rectangle().frame(width: 6) }
                }
            }
    }

    // Zig-zag torn bottom edge of the thermal receipt.
    private var tornEdge: some View {
        TornEdge()
            .fill(Theme.paper)
            .frame(height: 12)
    }
}

private struct ReceiptRow: View {
    let item: HistoryItem

    private var when: String {
        let f = DateFormatter()
        f.dateFormat = "MMM dd  HH:mm"
        return f.string(from: item.record.timestamp)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(when).foregroundColor(Color(hex: 0x7A7468))
                Text(shortModel(item.record.model)).fontWeight(.bold)
                Spacer()
                Text(String(format: "%.4f", item.cost))
                    .foregroundColor(item.isOverkill ? Color(hex: 0xC0392B) : Theme.paperInk)
            }
            .font(.system(size: 11.5, design: .monospaced))

            if !item.record.promptPreview.isEmpty {
                Text(item.record.promptPreview)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: 0x8A8478))
                    .lineLimit(1)
            }
            if item.isOverkill {
                Text("⚠ overkill — Haiku saves \(String(format: "%.4f", item.overpay))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: 0xC0392B))
            }
        }
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(hex: 0xD8D2C4)).frame(height: 1)
                .mask {
                    HStack(spacing: 4) { ForEach(0..<50, id: \.self) { _ in Rectangle().frame(width: 5) } }
                }
        }
    }
}

private struct TornEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 12
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        var x: CGFloat = rect.width
        var down = true
        while x > 0 {
            let nextX = max(0, x - step)
            p.addLine(to: CGPoint(x: nextX, y: down ? rect.height : 0))
            x = nextX
            down.toggle()
        }
        p.closeSubpath()
        return p
    }
}
