import SwiftUI
import AppKit
import TokenWatchCore

struct AdvisorView: View {
    @EnvironmentObject var store: UsageStore
    @State private var prompt: String = ""
    @State private var recommendation: Recommendation?
    @State private var runOutput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model Advisor").font(.headline)
            TextEditor(text: $prompt)
                .frame(height: 120)
                .border(Color.gray.opacity(0.3))
            Button("Recommend") { recommendation = store.advisor.recommend(prompt: prompt) }
            if let rec = recommendation {
                HStack {
                    Text(chip(rec.tier)).bold()
                    Text(String(format: "~$%.4f", rec.estimatedCost)).foregroundColor(.secondary)
                }
                Button("Run in Claude Code") { run(rec) }
            }
            if !runOutput.isEmpty {
                ScrollView { Text(runOutput).font(.system(.caption, design: .monospaced)) }
                    .frame(maxHeight: 120)
            }
            Spacer()
        }
        .padding()
    }

    private func chip(_ tier: ModelTier) -> String {
        switch tier {
        case .haiku:  return "🟢 Haiku"
        case .sonnet: return "🟡 Sonnet"
        case .opus:   return "🔴 Opus"
        }
    }

    private func run(_ rec: Recommendation) {
        let args = store.advisor.runCommand(prompt: prompt, alias: rec.cliAlias)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            runOutput = String(data: data, encoding: .utf8) ?? ""
        } catch {
            runOutput = "Could not launch `claude`. Is Claude Code installed and on PATH?\n\(error.localizedDescription)"
        }
    }
}
