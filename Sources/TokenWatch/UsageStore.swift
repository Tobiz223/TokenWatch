import Foundation
import Combine
import TokenWatchCore

struct HistoryItem: Identifiable {
    let id: String
    let record: UsageRecord
    let cost: Double
    let isOverkill: Bool
    let overpay: Double
}

struct ModelSpend: Identifiable {
    let id: String        // full model id
    let short: String     // "Opus" / "Sonnet" / "Haiku"
    let cost: Double
}

func shortModel(_ m: String) -> String {
    if m.contains("opus") { return "Opus" }
    if m.contains("sonnet") { return "Sonnet" }
    if m.contains("haiku") { return "Haiku" }
    return m
}

@MainActor
final class UsageStore: ObservableObject {
    @Published var monthToDate: Double = 0
    @Published var allTime: Double = 0
    @Published var overkillCount: Int = 0
    @Published var totalOverpay: Double = 0
    @Published var history: [HistoryItem] = []
    @Published var requests: [RequestGroup] = []
    @Published var requestCount: Int = 0
    @Published var byModel: [ModelSpend] = []
    @Published var updatedAt: String = "—"

    /// Formatted month-to-date figure shown in the menu bar (e.g. "$47.80").
    var monthToDateText: String { String(format: "$%.2f", monthToDate) }

    let advisor: Advisor
    private let rootPath: String
    private let parser = LogParser()
    private let costEngine: CostEngine
    private let detector: OverkillDetector
    private let grouper: RequestGrouper
    private var watcher: FileWatcher?

    init(rootPath: String = NSString(string: "~/.claude/projects").expandingTildeInPath) {
        self.rootPath = rootPath
        let pricing = PricingTable.bundled()
        self.costEngine = CostEngine(pricing: pricing)
        self.detector = OverkillDetector(costEngine: costEngine)
        self.grouper = RequestGrouper(costEngine: costEngine, detector: detector)
        self.advisor = Advisor(costEngine: costEngine)
        refresh()
    }

    func startWatching() {
        watcher = FileWatcher(path: rootPath) { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        watcher?.start()
    }

    func refresh() {
        let records = loadAllRecords()
        let cal = Calendar.current

        var items: [HistoryItem] = []
        var byModelTotals: [String: Double] = [:]
        var overpaySum = 0.0
        var overkills = 0
        var all = 0.0

        for r in records {
            let cost = costEngine.cost(for: r)
            all += cost
            byModelTotals[r.model, default: 0] += cost
            let res = detector.evaluate(r)
            if res.isOverkill { overkills += 1; overpaySum += res.overpay }
            items.append(HistoryItem(id: r.id ?? UUID().uuidString, record: r,
                                     cost: cost, isOverkill: res.isOverkill, overpay: res.overpay))
        }

        monthToDate = costEngine.monthToDateTotal(records, now: Date(), calendar: cal)
        allTime = all
        overkillCount = overkills
        totalOverpay = overpaySum
        history = items.sorted { $0.record.timestamp > $1.record.timestamp }
        requests = grouper.groups(from: records, limit: 200)
        requestCount = records.count
        byModel = byModelTotals
            .map { ModelSpend(id: $0.key, short: shortModel($0.key), cost: $0.value) }
            .sorted { $0.cost > $1.cost }

        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        updatedAt = f.string(from: Date())
    }

    private func loadAllRecords() -> [UsageRecord] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: rootPath) else { return [] }
        var records: [UsageRecord] = []
        for case let rel as String in enumerator where rel.hasSuffix(".jsonl") {
            let full = (rootPath as NSString).appendingPathComponent(rel)
            if let contents = try? String(contentsOfFile: full, encoding: .utf8) {
                records += parser.parse(fileContents: contents, project: "unknown", source: rel)
            }
        }
        return records
    }
}
