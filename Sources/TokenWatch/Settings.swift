import Foundation
import Combine

enum Lang: String { case en, uk }
enum Currency: String { case usd, uah }

/// App-wide language + currency preferences, persisted in UserDefaults, plus the
/// localization table and money/number formatting used across every view.
@MainActor
final class Settings: ObservableObject {
    @Published var lang: Lang { didSet { defaults.set(lang.rawValue, forKey: "tw_lang") } }
    @Published var currency: Currency { didSet { defaults.set(currency.rawValue, forKey: "tw_cur") } }

    /// Editable FX rate — hryvnia per 1 US dollar.
    let uahPerUsd = 41.5
    private let defaults = UserDefaults.standard

    init() {
        lang = Lang(rawValue: defaults.string(forKey: "tw_lang") ?? "en") ?? .en
        currency = Currency(rawValue: defaults.string(forKey: "tw_cur") ?? "usd") ?? .usd
    }

    // MARK: Localization

    func t(_ key: String) -> String { (strings[lang]?[key]) ?? key }

    func overkillMessage(amount: String, count: Int) -> String {
        switch lang {
        case .en: return "You overpaid \(amount) on \(count) simple task\(count == 1 ? "" : "s") — Haiku would have covered them."
        case .uk: return "Ви переплатили \(amount) на \(count) \(count == 1 ? "простій задачі" : "простих задачах") — вистачило б Haiku."
        }
    }
    func overkillFlag(amount: String) -> String {
        lang == .en ? "overkill — Haiku saves \(amount)" : "перевитрата — Haiku зекономив би \(amount)"
    }

    // MARK: Formatting

    func money(_ usd: Double, precise: Bool = false) -> String {
        let value = currency == .uah ? usd * uahPerUsd : usd
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency == .uah ? "UAH" : "USD"
        f.locale = Locale(identifier: lang == .uk ? "uk_UA" : "en_US")
        f.minimumFractionDigits = precise ? 4 : 2
        f.maximumFractionDigits = precise ? 4 : 2
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    func num(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: lang == .uk ? "uk_UA" : "en_US")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: Strings table

    private let strings: [Lang: [String: String]] = [
        .en: [
            "tagline": "AI spend tracker",
            "tab_overview": "Overview", "tab_history": "History", "tab_advisor": "Advisor",
            "month_to_date": "Month to date", "meter_run": "accruing this month",
            "all_time": "All-time spend", "requests": "Requests", "by_model": "Spend by model",
            "col_time": "Time", "col_model": "Model", "col_tokens": "Tokens", "col_cost": "Cost",
            "of_all_time": "of all-time", "empty": "No requests found yet.",
            "advisor_title": "Model advisor",
            "advisor_lead": "Describe your task. TokenWatch asks Claude Haiku to read it and pick the cheapest model that can handle the situation — then hands you the command.",
            "placeholder": "e.g. our checkout total is occasionally wrong; find out why\nor: rename a variable across the file",
            "analyze": "Analyze & recommend", "analyzing": "Claude Haiku is analyzing the task…",
            "confidence": "confidence", "saves": "saves", "vs_opus": "vs Opus",
            "copy": "copy", "copied": "copied ✓", "for_task": "for this task",
            "via_haiku": "analyzed by Claude Haiku", "via_offline": "offline heuristic",
        ],
        .uk: [
            "tagline": "облік витрат на ШІ",
            "tab_overview": "Огляд", "tab_history": "Історія", "tab_advisor": "Порадник",
            "month_to_date": "За поточний місяць", "meter_run": "накопичується цього місяця",
            "all_time": "Витрати за весь час", "requests": "Запити", "by_model": "Витрати за моделями",
            "col_time": "Час", "col_model": "Модель", "col_tokens": "Токени", "col_cost": "Вартість",
            "of_all_time": "від усього часу", "empty": "Запитів поки не знайдено.",
            "advisor_title": "Порадник моделі",
            "advisor_lead": "Опишіть задачу. TokenWatch попросить Claude Haiku прочитати її й обрати найдешевшу модель, що впорається із ситуацією — і дасть готову команду.",
            "placeholder": "напр. підсумок у кошику інколи невірний; з’ясуй чому\nабо: перейменувати змінну у файлі",
            "analyze": "Проаналізувати", "analyzing": "Claude Haiku аналізує задачу…",
            "confidence": "впевненість", "saves": "економія", "vs_opus": "проти Opus",
            "copy": "копіювати", "copied": "скопійовано ✓", "for_task": "на цю задачу",
            "via_haiku": "проаналізовано Claude Haiku", "via_offline": "офлайн-евристика",
        ],
    ]
}
