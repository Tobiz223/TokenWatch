import SwiftUI
import AppKit
import TokenWatchCore

struct AdvisorView: View {
    @EnvironmentObject var store: UsageStore
    @EnvironmentObject var settings: Settings
    @State private var prompt: String = ""
    @State private var analysis: TaskAnalysis?
    @State private var recommendation: Recommendation?
    @State private var savings: Double = 0
    @State private var source: String = ""      // "haiku" | "offline"
    @State private var command: String = ""
    @State private var loading = false
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(settings.t("advisor_title")).padding(.top, 16)
                Text(settings.t("advisor_lead"))
                    .font(.system(size: 12.5)).foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 8)

                promptField.padding(.top, 12)
                analyzeButton.padding(.top, 11)

                if loading { loadingRow.padding(.top, 15) }
                if let a = analysis, let rec = recommendation, !loading {
                    verdict(a, rec).padding(.top, 16)
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18).padding(.bottom, 18)
        }
    }

    private var promptField: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10).fill(Theme.track)
            RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1)
            if prompt.isEmpty {
                Text(settings.t("placeholder"))
                    .font(.system(size: 13)).foregroundColor(Theme.faint)
                    .padding(.horizontal, 13).padding(.vertical, 12).allowsHitTesting(false)
            }
            TextEditor(text: $prompt)
                .font(.system(size: 13)).foregroundColor(Theme.text)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 9).padding(.vertical, 8)
        }
        .frame(height: 92)
    }

    private var analyzeButton: some View {
        Button(action: analyze) {
            Text(loading ? settings.t("analyzing") : settings.t("analyze"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: 0x231705))
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
                .opacity(loading ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(loading || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var loadingRow: some View {
        HStack(spacing: 9) {
            ProgressView().controlSize(.small)
            Text(settings.t("analyzing")).font(.system(size: 12.5)).foregroundColor(Theme.muted)
        }
    }

    @ViewBuilder private func verdict(_ a: TaskAnalysis, _ rec: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Circle().fill(chipColor(a.tier)).frame(width: 7, height: 7)
                    Text(tierName(a.tier)).font(.system(size: 12.5, weight: .semibold))
                }
                .padding(.horizontal, 11).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))

                Text("≈ \(settings.money(rec.estimatedCost, precise: true)) \(settings.t("for_task"))")
                    .font(.system(size: 12, design: .monospaced)).foregroundColor(Theme.muted)
            }

            if !a.situation.isEmpty {
                Text(a.situation).font(.system(size: 15, weight: .semibold))
            }
            if !a.reasoning.isEmpty {
                Text(a.reasoning).font(.system(size: 12.5)).foregroundColor(Color(hex: 0xBFCADC))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 16) {
                Text(source == "haiku" ? "🧠 \(settings.t("via_haiku"))" : "⚙ \(settings.t("via_offline"))")
                Text("\(settings.t("confidence")) \(Int(a.confidence * 100))%")
                Text("\(settings.t("saves")) \(settings.money(savings, precise: true)) \(settings.t("vs_opus"))")
            }
            .font(.system(size: 10.5, design: .monospaced)).foregroundColor(Theme.faint)

            commandBox
        }
    }

    private var commandBox: some View {
        ZStack(alignment: .topTrailing) {
            Text(command)
                .font(.system(size: 11.5, design: .monospaced)).foregroundColor(Color(hex: 0xBFD4F5))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 46).padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.track))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
            Button(action: copyCommand) {
                Text(copied ? settings.t("copied") : settings.t("copy"))
                    .font(.system(size: 10.5, design: .monospaced)).foregroundColor(Theme.muted)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface2))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain).padding(8)
        }
    }

    // MARK: - Actions

    private func analyze() {
        let task = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !task.isEmpty else { return }
        loading = true; copied = false
        Task {
            let output = await runClaude(prompt: TaskAnalyzer.classificationPrompt(for: task))
            let parsed = output.flatMap { TaskAnalyzer.parse(response: $0) }
            await MainActor.run { apply(parsed: parsed, hadOutput: output != nil, task: task) }
        }
    }

    private func apply(parsed: TaskAnalysis?, hadOutput: Bool, task: String) {
        let result: TaskAnalysis
        if let p = parsed {
            result = p; source = "haiku"
        } else {
            let tier = store.advisor.heuristics.recommend(prompt: task)
            result = TaskAnalysis(tier: tier, situation: settings.t("via_offline"),
                                  reasoning: "", confidence: 0.5)
            source = "offline"
        }
        let rec = store.advisor.recommendation(tier: result.tier, prompt: task)
        analysis = result
        recommendation = rec
        savings = max(0, store.advisor.opusCost(prompt: task) - rec.estimatedCost)
        command = store.advisor.runCommand(prompt: task, alias: rec.cliAlias).joined(separator: " ")
        loading = false
    }

    private func runClaude(prompt: String) async -> String? {
        await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                p.arguments = ["claude", "-p", prompt, "--model", "haiku"]
                let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
                do {
                    try p.run()
                    let data = out.fileHandleForReading.readDataToEndOfFile()
                    p.waitUntilExit()
                    cont.resume(returning: p.terminationStatus == 0 ? String(data: data, encoding: .utf8) : nil)
                } catch { cont.resume(returning: nil) }
            }
        }
    }

    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        copied = true
    }

    private func tierName(_ tier: ModelTier) -> String {
        switch tier { case .haiku: return "Haiku"; case .sonnet: return "Sonnet"; case .opus: return "Opus" }
    }
    private func chipColor(_ tier: ModelTier) -> Color {
        switch tier { case .haiku: return Theme.green; case .sonnet: return Theme.amber; case .opus: return Theme.red }
    }
}
