import Foundation

public struct UsageRecord: Equatable {
    public let id: String?
    public let timestamp: Date
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheWriteTokens: Int
    public let cacheReadTokens: Int
    public let promptPreview: String
    public let project: String

    public init(id: String?, timestamp: Date, model: String,
                inputTokens: Int, outputTokens: Int,
                cacheWriteTokens: Int, cacheReadTokens: Int,
                promptPreview: String, project: String) {
        self.id = id
        self.timestamp = timestamp
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.cacheReadTokens = cacheReadTokens
        self.promptPreview = promptPreview
        self.project = project
    }
}
