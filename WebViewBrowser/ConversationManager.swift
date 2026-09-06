import Foundation

// MARK: - 会话模型
struct Conversation: Codable, Equatable {
    var id: String
    var title: String
    var messages: [ChatMessage]
    var createdAt: TimeInterval
    var updatedAt: TimeInterval
    var isPinned: Bool
    var model: String?
    
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - 会话管理器
class ConversationManager {
    static let shared = ConversationManager()
    
    private let conversationsKey = "ai_conversations"
    private let currentConversationKey = "ai_current_conversation_id"
    
    private init() {
        // 迁移旧数据（如果有）
        migrateIfNeeded()
    }
    
    // MARK: - 会话管理
    func loadConversations() -> [Conversation] {
        guard let data = UserDefaults.standard.data(forKey: conversationsKey),
              let conversations = try? JSONDecoder().decode([Conversation].self, from: data) else {
            return []
        }
        // 按更新时间排序，置顶优先
        return conversations.sorted { (c1, c2) -> Bool in
            if c1.isPinned != c2.isPinned { return c1.isPinned }
            return c1.updatedAt > c2.updatedAt
        }
    }
    
    func saveConversations(_ conversations: [Conversation]) {
        if let data = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(data, forKey: conversationsKey)
        }
    }
    
    func createConversation(title: String = "新对话") -> Conversation {
        let conversation = Conversation(
            id: UUID().uuidString,
            title: title,
            messages: [],
            createdAt: Date().timeIntervalSince1970,
            updatedAt: Date().timeIntervalSince1970,
            isPinned: false,
            model: nil
        )
        var conversations = loadConversations()
        conversations.insert(conversation, at: 0)
        saveConversations(conversations)
        currentConversationID = conversation.id
        return conversation
    }
    
    func updateConversation(_ conversation: Conversation) {
        var conversations = loadConversations()
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            var updated = conversation
            updated.updatedAt = Date().timeIntervalSince1970
            conversations[index] = updated
            saveConversations(conversations)
        }
    }
    
    func deleteConversation(_ conversation: Conversation) {
        var conversations = loadConversations()
        conversations.removeAll { $0.id == conversation.id }
        saveConversations(conversations)
        if currentConversationID == conversation.id {
            currentConversationID = nil
        }
    }
    
    func renameConversation(_ conversation: Conversation, title: String) {
        var conversations = loadConversations()
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index].title = title
            saveConversations(conversations)
        }
    }
    
    func togglePin(_ conversation: Conversation) {
        var conversations = loadConversations()
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index].isPinned.toggle()
            saveConversations(conversations)
        }
    }
    
    // MARK: - 当前会话
    var currentConversationID: String? {
        get { UserDefaults.standard.string(forKey: currentConversationKey) }
        set { UserDefaults.standard.set(newValue, forKey: currentConversationKey) }
    }
    
    func currentConversation() -> Conversation? {
        guard let id = currentConversationID else { return nil }
        return loadConversations().first { $0.id == id }
    }
    
    // MARK: - 搜索
    func searchConversations(_ query: String) -> [Conversation] {
        let lowerQuery = query.lowercased()
        return loadConversations().filter { conversation in
            if conversation.title.lowercased().contains(lowerQuery) { return true }
            return conversation.messages.contains { $0.content.lowercased().contains(lowerQuery) }
        }
    }
    
    // MARK: - 导出
    func exportConversation(_ conversation: Conversation, format: String = "md") -> String {
        var text = "# \(conversation.title)\n\n"
        text += "> 创建时间：\(Date(timeIntervalSince1970: conversation.createdAt))\n\n"
        text += "---\n\n"
        for msg in conversation.messages {
            let role = msg.role == "user" ? "👤 用户" : "🤖 AI"
            text += "## \(role)\n\n\(msg.content)\n\n"
        }
        return text
    }
    
    // MARK: - 自动生成标题
    func generateTitle(for messages: [ChatMessage]) -> String {
        guard let firstUserMessage = messages.first(where: { $0.role == "user" }) else {
            return "新对话"
        }
        let content = firstUserMessage.content
        if content.count > 20 {
            return String(content.prefix(20)) + "..."
        }
        return content
    }
    
    // MARK: - 迁移
    private func migrateIfNeeded() {
        // 未来版本迁移用
    }
    
    // MARK: - 按时间分组
    func groupedConversations() -> [(String, [Conversation])] {
        let conversations = loadConversations()
        let calendar = Calendar.current
        var groups: [String: [Conversation]] = [:]
        
        for conv in conversations {
            let date = Date(timeIntervalSince1970: conv.updatedAt)
            let groupName: String
            if calendar.isDateInToday(date) {
                groupName = "今天"
            } else if calendar.isDateInYesterday(date) {
                groupName = "昨天"
            } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
                groupName = "本周"
            } else if calendar.isDate(date, equalTo: Date(), toGranularity: .month) {
                groupName = "本月"
            } else {
                groupName = "更早"
            }
            groups[groupName, default: []].append(conv)
        }
        
        let order = ["今天", "昨天", "本周", "本月", "更早"]
        return order.compactMap { name in
            if let convs = groups[name], !convs.isEmpty {
                return (name, convs)
            }
            return nil
        }
    }
}
