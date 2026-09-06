import Foundation

// MARK: - API 配置模型
struct APIConfig: Codable, Equatable {
    var id: String
    var name: String           // 厂商名称，如"腾讯混元"、"OpenAI"
    var baseURL: String        // API 地址，如 https://tokenhub.tencentmaas.com/v1
    var apiKey: String         // API Key
    var models: [String]       // 可用模型列表
    var isDefault: Bool        // 是否默认
    
    static func == (lhs: APIConfig, rhs: APIConfig) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - 对话消息
struct ChatMessage: Codable, Equatable {
    var role: String    // user / assistant / system
    var content: String
    var timestamp: TimeInterval
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.timestamp == rhs.timestamp && lhs.role == rhs.role
    }
}

// MARK: - 对话参数
struct ChatParams: Codable {
    var temperature: Double = 0.7
    var maxTokens: Int = 2048
    var topP: Double = 1.0
    var systemPrompt: String = "你是一个有帮助的AI助手。"
}

// MARK: - AI 模型管理器
class AIModelManager {
    static let shared = AIModelManager()
    
    private let configsKey = "ai_api_configs"
    private let paramsKey = "ai_chat_params"
    private let currentConfigKey = "ai_current_config_id"
    private let currentModelKey = "ai_current_model"
    
    private init() {
        // 首次启动时添加默认配置
        if loadConfigs().isEmpty {
            let defaultConfig = APIConfig(
                id: UUID().uuidString,
                name: "腾讯混元",
                baseURL: "https://tokenhub.tencentmaas.com/v1",
                apiKey: "",
                models: ["hy-mt2-lite", "hy-mt2-plus", "hy-mt2-pro", "hy3", "hy4-preview"],
                isDefault: true
            )
            saveConfigs([defaultConfig])
        }
    }
    
    // MARK: - 配置管理
    func loadConfigs() -> [APIConfig] {
        guard let data = UserDefaults.standard.data(forKey: configsKey),
              let configs = try? JSONDecoder().decode([APIConfig].self, from: data) else {
            return []
        }
        return configs
    }
    
    func saveConfigs(_ configs: [APIConfig]) {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: configsKey)
        }
    }
    
    func addConfig(_ config: APIConfig) {
        var configs = loadConfigs()
        if config.isDefault {
            configs = configs.map { var c = $0; c.isDefault = false; return c }
        }
        configs.append(config)
        saveConfigs(configs)
    }
    
    func updateConfig(_ config: APIConfig) {
        var configs = loadConfigs()
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            if config.isDefault {
                configs = configs.map { var c = $0; c.isDefault = false; return c }
            }
            configs[index] = config
            saveConfigs(configs)
        }
    }
    
    func deleteConfig(_ config: APIConfig) {
        var configs = loadConfigs()
        configs.removeAll { $0.id == config.id }
        if configs.isEmpty {
            // 至少保留一个空配置
            let empty = APIConfig(id: UUID().uuidString, name: "新配置", baseURL: "", apiKey: "", models: [], isDefault: true)
            configs.append(empty)
        } else if configs.allSatisfy({ !$0.isDefault }) {
            configs[0].isDefault = true
        }
        saveConfigs(configs)
    }
    
    func defaultConfig() -> APIConfig? {
        let configs = loadConfigs()
        return configs.first { $0.isDefault } ?? configs.first
    }
    
    // MARK: - 当前选择
    var currentConfigID: String? {
        get { UserDefaults.standard.string(forKey: currentConfigKey) }
        set { UserDefaults.standard.set(newValue, forKey: currentConfigKey) }
    }
    
    var currentModel: String {
        get { UserDefaults.standard.string(forKey: currentModelKey) ?? "hy-mt2-lite" }
        set { UserDefaults.standard.set(newValue, forKey: currentModelKey) }
    }
    
    func currentConfig() -> APIConfig? {
        let configs = loadConfigs()
        if let id = currentConfigID, let config = configs.first(where: { $0.id == id }) {
            return config
        }
        return defaultConfig()
    }
    
    // MARK: - 对话参数
    func loadParams() -> ChatParams {
        guard let data = UserDefaults.standard.data(forKey: paramsKey),
              let params = try? JSONDecoder().decode(ChatParams.self, from: data) else {
            return ChatParams()
        }
        return params
    }
    
    func saveParams(_ params: ChatParams) {
        if let data = try? JSONEncoder().encode(params) {
            UserDefaults.standard.set(data, forKey: paramsKey)
        }
    }
    
    // MARK: - 获取模型列表
    func fetchModels(for config: APIConfig, completion: @escaping ([String]?, Error?) -> Void) {
        guard let url = URL(string: config.baseURL.hasSuffix("/v1") ? config.baseURL + "/models" : config.baseURL + "/v1/models") else {
            completion(nil, NSError(domain: "AIModelManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "API地址无效"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(nil, error) }
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modelsData = json["data"] as? [[String: Any]] else {
                DispatchQueue.main.async { completion(nil, NSError(domain: "AIModelManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "解析模型列表失败"])) }
                return
            }
            let models = modelsData.compactMap { $0["id"] as? String }
            DispatchQueue.main.async { completion(models, nil) }
        }.resume()
    }
    
    // MARK: - 发送对话（非流式）
    func sendChat(messages: [ChatMessage],
                  config: APIConfig,
                  model: String,
                  params: ChatParams,
                  completion: @escaping (String?, Error?) -> Void) {
        let baseURL = config.baseURL.hasSuffix("/") ? String(config.baseURL.dropLast()) : config.baseURL
        guard let url = URL(string: baseURL + "/chat/completions") else {
            completion(nil, NSError(domain: "AIModelManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "API地址无效"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        var messageArray: [[String: String]] = []
        // 添加 system prompt
        if !params.systemPrompt.isEmpty {
            messageArray.append(["role": "system", "content": params.systemPrompt])
        }
        for msg in messages {
            messageArray.append(["role": msg.role, "content": msg.content])
        }
        
        let body: [String: Any] = [
            "model": model,
            "messages": messageArray,
            "temperature": params.temperature,
            "max_tokens": params.maxTokens,
            "top_p": params.topP,
            "stream": false
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(nil, error) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(nil, NSError(domain: "AIModelManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "无响应数据"])) }
                return
            }
            
            // 解析响应
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let content = message["content"] as? String {
                DispatchQueue.main.async { completion(content, nil) }
            } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let error = json["error"] as? [String: Any],
                      let message = error["message"] as? String {
                DispatchQueue.main.async { completion(nil, NSError(domain: "AIModelManager", code: -4, userInfo: [NSLocalizedDescriptionKey: message])) }
            } else {
                DispatchQueue.main.async { completion(nil, NSError(domain: "AIModelManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "响应解析失败"])) }
            }
        }.resume()
    }
    
    // MARK: - 预设厂商模板
    static let presetTemplates: [(name: String, baseURL: String)] = [
        ("腾讯混元", "https://tokenhub.tencentmaas.com/v1"),
        ("OpenAI", "https://api.openai.com/v1"),
        ("DeepSeek", "https://api.deepseek.com/v1"),
        ("通义千问", "https://dashscope.aliyuncs.com/compatible-mode/v1"),
        ("智谱清言", "https://open.bigmodel.cn/api/paas/v4"),
        ("Kimi", "https://api.moonshot.cn/v1"),
        ("豆包", "https://ark.cn-beijing.volces.com/api/v3"),
        ("自定义", "")
    ]
    
    // MARK: - 流式输出
    private var streamTask: URLSessionDataTask?
    private var streamDelegate: StreamDelegate?
    
    func streamChat(messages: [ChatMessage],
                    config: APIConfig,
                    model: String,
                    params: ChatParams,
                    onToken: @escaping (String) -> Void,
                    completion: @escaping (String?, Error?) -> Void) {
        let baseURL = config.baseURL.hasSuffix("/") ? String(config.baseURL.dropLast()) : config.baseURL
        guard let url = URL(string: baseURL + "/chat/completions") else {
            completion(nil, NSError(domain: "AIModelManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "API地址无效"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        
        var messageArray: [[String: String]] = []
        if !params.systemPrompt.isEmpty {
            messageArray.append(["role": "system", "content": params.systemPrompt])
        }
        for msg in messages {
            messageArray.append(["role": msg.role, "content": msg.content])
        }
        
        let body: [String: Any] = [
            "model": model,
            "messages": messageArray,
            "temperature": params.temperature,
            "max_tokens": params.maxTokens,
            "top_p": params.topP,
            "stream": true
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let delegate = StreamDelegate(onToken: onToken, completion: completion)
        self.streamDelegate = delegate
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)
        streamTask = session.dataTask(with: request)
        streamTask?.resume()
    }
    
    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        streamDelegate = nil
    }
    
    // MARK: - Token 统计
    private(set) var totalTokensUsed: Int = 0
    private(set) var totalRequests: Int = 0
    
    func recordTokens(_ tokens: Int) {
        totalTokensUsed += tokens
        totalRequests += 1
        UserDefaults.standard.set(totalTokensUsed, forKey: "ai_total_tokens")
        UserDefaults.standard.set(totalRequests, forKey: "ai_total_requests")
    }
    
    func loadTokenStats() {
        totalTokensUsed = UserDefaults.standard.integer(forKey: "ai_total_tokens")
        totalRequests = UserDefaults.standard.integer(forKey: "ai_total_requests")
    }
    
    func resetTokenStats() {
        totalTokensUsed = 0
        totalRequests = 0
        UserDefaults.standard.removeObject(forKey: "ai_total_tokens")
        UserDefaults.standard.removeObject(forKey: "ai_total_requests")
    }
}

// MARK: - 流式输出 Delegate
class StreamDelegate: NSObject, URLSessionDataDelegate {
    private var buffer = ""
    private var fullResponse = ""
    private let onToken: (String) -> Void
    private let completion: (String?, Error?) -> Void
    private var lastFlushTime = Date()
    
    init(onToken: @escaping (String) -> Void, completion: @escaping (String?, Error?) -> Void) {
        self.onToken = onToken
        self.completion = completion
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text
        
        // 解析 SSE: data: {...}\n\n
        let events = buffer.components(separatedBy: "\n\n")
        buffer = events.last ?? ""
        
        for event in events.dropLast() {
            let lines = event.components(separatedBy: "\n")
            for line in lines {
                if line.hasPrefix("data: ") {
                    let jsonStr = String(line.dropFirst(6))
                    if jsonStr == "[DONE]" {
                        completion(fullResponse, nil)
                        return
                    }
                    if let jsonData = jsonStr.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let first = choices.first,
                       let delta = first["delta"] as? [String: Any],
                       let content = delta["content"] as? String {
                        fullResponse += content
                        // 节流刷新，每30ms刷新一次
                        let now = Date()
                        if now.timeIntervalSince(lastFlushTime) > 0.03 {
                            onToken(content)
                            lastFlushTime = now
                        } else {
                            // 缓冲，稍后刷新
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
                                self?.flushBuffer()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func flushBuffer() {
        // 缓冲已在 onToken 中处理，这里仅用于节流
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            if (error as NSError).code == NSURLErrorCancelled {
                completion(fullResponse, nil) // 用户主动停止
            } else {
                completion(nil, error)
            }
        } else if !fullResponse.isEmpty {
            completion(fullResponse, nil)
        }
    }
}
