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

@MainActor
final class UsageStore: ObservableObject {
    @Published var monthToDateText: String = "—"
    @Published var history: [HistoryItem] = []
    @Published var totalOverpay: Double = 0

    let advisor: Advisor
    private let rootPath: String
    private let parser = LogParser()
    private let costEngine: CostEngine
    private let detector: OverkillDetector
    private var watcher: FileWatcher?

    init(rootPath: String = NSString(string: "~/.claude/projects").expandingTildeInPath) {
        self.rootPath = rootPath
        let pricing = PricingTable.bundled()
        self.costEngine = CostEngine(pricing: pricing)
        self.detector = OverkillDetector(costEngine: costEngine)
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
        let mtd = costEngine.monthToDateTotal(records, now: Date(), calendar: cal)
        monthToDateText = String(format: "$%.2f", mtd)

        var items: [HistoryItem] = []
        var overpaySum = 0.0
        for r in records {
            let res = detector.evaluate(r)
            overpaySum += res.overpay
            items.append(HistoryItem(id: r.id ?? UUID().uuidString, record: r,
                                     cost: costEngine.cost(for: r),
                                     isOverkill: res.isOverkill, overpay: res.overpay))
        }
        history = items.sorted { $0.record.timestamp > $1.record.timestamp }
        totalOverpay = overpaySum
    }

    private func loadAllRecords() -> [UsageRecord] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: rootPath) else { return [] }
        var records: [UsageRecord] = []
        for case let rel as String in enumerator where rel.hasSuffix(".jsonl") {
            let full = (rootPath as NSString).appendingPathComponent(rel)
            if let contents = try? String(contentsOfFile: full, encoding: .utf8) {
                records += parser.parse(fileContents: contents, project: "unknown")
            }
        }
        return records
    }
}
