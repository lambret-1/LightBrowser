import Foundation

// MARK: - 知识库文档模型
struct KnowledgeDocument: Codable, Equatable {
    var id: String
    var name: String
    var content: String
    var fileType: String
    var size: Int
    var createdAt: TimeInterval
    var chunks: [KnowledgeChunk]
    
    static func == (lhs: KnowledgeDocument, rhs: KnowledgeDocument) -> Bool {
        return lhs.id == rhs.id
    }
}

struct KnowledgeChunk: Codable {
    var id: String
    var content: String
    var embedding: [Float]?
}

// MARK: - 知识库管理器
class KnowledgeBaseManager {
    static let shared = KnowledgeBaseManager()
    
    private let documentsKey = "ai_knowledge_documents"
    private let basePath: String
    
    private init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        basePath = paths[0].path + "/AIKnowledgeBase"
        try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true)
    }
    
    // MARK: - 文档管理
    func loadDocuments() -> [KnowledgeDocument] {
        guard let data = UserDefaults.standard.data(forKey: documentsKey),
              let docs = try? JSONDecoder().decode([KnowledgeDocument].self, from: data) else {
            return []
        }
        return docs.sorted { $0.createdAt > $1.createdAt }
    }
    
    func saveDocuments(_ docs: [KnowledgeDocument]) {
        if let data = try? JSONEncoder().encode(docs) {
            UserDefaults.standard.set(data, forKey: documentsKey)
        }
    }
    
    func addDocument(name: String, content: String, fileType: String) -> KnowledgeDocument {
        // 分块（每500字符一块，重叠50字符）
        let chunks = chunkContent(content, chunkSize: 500, overlap: 50)
        let doc = KnowledgeDocument(
            id: UUID().uuidString,
            name: name,
            content: content,
            fileType: fileType,
            size: content.count,
            createdAt: Date().timeIntervalSince1970,
            chunks: chunks
        )
        var docs = loadDocuments()
        docs.insert(doc, at: 0)
        saveDocuments(docs)
        return doc
    }
    
    func deleteDocument(_ doc: KnowledgeDocument) {
        var docs = loadDocuments()
        docs.removeAll { $0.id == doc.id }
        saveDocuments(docs)
    }
    
    // MARK: - 分块
    private func chunkContent(_ content: String, chunkSize: Int, overlap: Int) -> [KnowledgeChunk] {
        var chunks: [KnowledgeChunk] = []
        let totalLength = content.count
        var start = 0
        
        while start < totalLength {
            let end = min(start + chunkSize, totalLength)
            let chunkContent = String(content[content.index(content.startIndex, offsetBy: start)..<content.index(content.startIndex, offsetBy: end)])
            chunks.append(KnowledgeChunk(id: UUID().uuidString, content: chunkContent, embedding: nil))
            if end >= totalLength { break }
            start = end - overlap
        }
        return chunks
    }
    
    // MARK: - 检索（简化版：关键词匹配）
    func search(_ query: String, topK: Int = 3) -> [String] {
        let docs = loadDocuments()
        var results: [(chunk: String, score: Int)] = []
        
        let queryWords = query.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        for doc in docs {
            for chunk in doc.chunks {
                var score = 0
                let lowerChunk = chunk.content.lowercased()
                for word in queryWords {
                    if lowerChunk.contains(word) {
                        score += 1
                    }
                }
                if score > 0 {
                    results.append((chunk.content, score))
                }
            }
        }
        
        results.sort { $0.score > $1.score }
        return Array(results.prefix(topK)).map { $0.chunk }
    }
    
    // MARK: - 构建提示词
    func buildPromptWithKnowledge(query: String) -> String {
        let relevantChunks = search(query)
        guard !relevantChunks.isEmpty else { return query }
        
        var prompt = "请根据以下知识库内容回答问题。如果知识库中没有相关信息，请直接回答。\n\n"
        prompt += "【知识库内容】\n"
        for (index, chunk) in relevantChunks.enumerated() {
            prompt += "[\(index + 1)] \(chunk)\n\n"
        }
        prompt += "【问题】\n\(query)\n\n"
        prompt += "【回答要求】\n- 优先使用知识库内容\n- 引用来源标注[数字]\n- 知识库没有的内容可以补充"
        return prompt
    }
    
    // MARK: - 统计
    var totalDocuments: Int { loadDocuments().count }
    var totalSize: Int { loadDocuments().reduce(0) { $0 + $1.size } }
}
