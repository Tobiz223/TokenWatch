import SwiftUI
import AppKit
import TokenWatchCore

struct AdvisorView: View {
    @EnvironmentObject var store: UsageStore
    @State private var prompt: String = ""
    @State private var recommendation: Recommendation?
    @State private var command: String = ""
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow("Model advisor").padding(.top, 16)
                Text("Paste a task. TokenWatch picks the cheapest model that can still handle it — and hands you the command to run it.")
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                promptField.padding(.top, 12)
                recommendButton.padding(.top, 12)

                if let rec = recommendation { verdict(rec).padding(.top, 16) }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private var promptField: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 11).fill(Theme.track)
            RoundedRectangle(cornerRadius: 11).stroke(Theme.hair, lineWidth: 1)
            if prompt.isEmpty {
                Text("e.g. rename a variable across the file\nor: debug the websocket reconnect race condition")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted.opacity(0.7))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $prompt)
                .font(.system(size: 13))
                .foregroundColor(Theme.text)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 9)
                .padding(.vertical, 8)
        }
        .frame(height: 96)
    }

    private var recommendButton: some View {
        Button(action: recommend) {
            Text("Recommend a model")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: 0x1A1206))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(LinearGradient(colors: [Theme.amber, Theme.amberDk],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func verdict(_ rec: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(chipLabel(rec.tier))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(chipColor(rec.tier).opacity(0.16)))
                    .overlay(Capsule().stroke(chipColor(rec.tier).opacity(0.4), lineWidth: 1))
                    .foregroundColor(chipColor(rec.tier))
                Text("≈ \(usd(rec.estimatedCost)) for this task")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.muted)
            }

            ZStack(alignment: .topTrailing) {
                Text(command)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundColor(Color(hex: 0xCFE0FF))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 44).padding(12)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Theme.track))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.hair, lineWidth: 1))

                Button(action: copyCommand) {
                    Text(copied ? "copied ✓" : "copy")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.slate2))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.hair, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
    }

    private func recommend() {
        let rec = store.advisor.recommend(prompt: prompt)
        recommendation = rec
        command = store.advisor.runCommand(prompt: prompt, alias: rec.cliAlias).joined(separator: " ")
        copied = false
    }

    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        copied = true
    }

    private func chipLabel(_ tier: ModelTier) -> String {
        switch tier {
        case .haiku:  return "🟢 Haiku"
        case .sonnet: return "🟡 Sonnet"
        case .opus:   return "🔴 Opus"
        }
    }

    private func chipColor(_ tier: ModelTier) -> Color {
        switch tier {
        case .haiku:  return Theme.mint
        case .sonnet: return Theme.amber
        case .opus:   return Theme.coral
        }
    }
}
