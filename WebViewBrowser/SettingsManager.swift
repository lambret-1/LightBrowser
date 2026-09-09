import UIKit

/// 统一设置管理器
/// 所有设置项集中管理，支持导入导出、重置
class SettingsManager: NSObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - 设置项 Keys
    private enum Keys {
        static let addressBarPosition = "settings_addressBarPosition" // top / bottom
        static let defaultSearchEngine = "settings_defaultSearchEngine" // baidu / google
        static let userAgent = "settings_userAgent" // iphone / ipad / windows / mac
        static let gestureSensitivity = "settings_gestureSensitivity" // 0.3 - 0.7
        static let menuAnimationDuration = "settings_menuAnimationDuration" // 0.2 - 1.0
        static let adBlockEnabled = "settings_adBlockEnabled"
        static let globalImageBlock = "settings_globalImageBlock"
        static let dnsPrefetchEnabled = "settings_dnsPrefetchEnabled"
        static let mediaAutoplayBlocked = "settings_mediaAutoplayBlocked"
        static let backgroundAnimationThrottle = "settings_backgroundAnimationThrottle"
        static let memoryWarningAutoClear = "settings_memoryWarningAutoClear"
        static let autoTranslateEnabled = "settings_autoTranslateEnabled"
        static let autoCheckUpdate = "settings_autoCheckUpdate"
        static let lastUpdateCheckTime = "settings_lastUpdateCheckTime"
    }
    
    private override init() {
        super.init()
        // 设置默认值
        defaults.register(defaults: [
            Keys.addressBarPosition: "top",
            Keys.defaultSearchEngine: "google",
            Keys.userAgent: "iphone",
            Keys.gestureSensitivity: 0.5,
            Keys.menuAnimationDuration: 0.6,
            Keys.adBlockEnabled: true,
            Keys.globalImageBlock: false,
            Keys.dnsPrefetchEnabled: true,
            Keys.mediaAutoplayBlocked: true,
            Keys.backgroundAnimationThrottle: true,
            Keys.memoryWarningAutoClear: true,
            Keys.autoTranslateEnabled: false,
            Keys.autoCheckUpdate: true
        ])
    }
    
    // MARK: - 通用设置
    var addressBarPosition: String {
        get { defaults.string(forKey: Keys.addressBarPosition) ?? "top" }
        set { defaults.set(newValue, forKey: Keys.addressBarPosition) }
    }
    
    var defaultSearchEngine: String {
        get { defaults.string(forKey: Keys.defaultSearchEngine) ?? "google" }
        set { defaults.set(newValue, forKey: Keys.defaultSearchEngine) }
    }
    
    var userAgent: String {
        get { defaults.string(forKey: Keys.userAgent) ?? "iphone" }
        set { defaults.set(newValue, forKey: Keys.userAgent) }
    }
    
    var gestureSensitivity: Double {
        get { defaults.double(forKey: Keys.gestureSensitivity) }
        set { defaults.set(newValue, forKey: Keys.gestureSensitivity) }
    }
    
    var menuAnimationDuration: Double {
        get { defaults.double(forKey: Keys.menuAnimationDuration) }
        set { defaults.set(newValue, forKey: Keys.menuAnimationDuration) }
    }
    
    // MARK: - 隐私与拦截
    var adBlockEnabled: Bool {
        get { defaults.bool(forKey: Keys.adBlockEnabled) }
        set { defaults.set(newValue, forKey: Keys.adBlockEnabled) }
    }
    
    var globalImageBlock: Bool {
        get { defaults.bool(forKey: Keys.globalImageBlock) }
        set { defaults.set(newValue, forKey: Keys.globalImageBlock) }
    }
    
    // MARK: - 性能
    var dnsPrefetchEnabled: Bool {
        get { defaults.bool(forKey: Keys.dnsPrefetchEnabled) }
        set { defaults.set(newValue, forKey: Keys.dnsPrefetchEnabled) }
    }
    
    var mediaAutoplayBlocked: Bool {
        get { defaults.bool(forKey: Keys.mediaAutoplayBlocked) }
        set { defaults.set(newValue, forKey: Keys.mediaAutoplayBlocked) }
    }
    
    var backgroundAnimationThrottle: Bool {
        get { defaults.bool(forKey: Keys.backgroundAnimationThrottle) }
        set { defaults.set(newValue, forKey: Keys.backgroundAnimationThrottle) }
    }
    
    var memoryWarningAutoClear: Bool {
        get { defaults.bool(forKey: Keys.memoryWarningAutoClear) }
        set { defaults.set(newValue, forKey: Keys.memoryWarningAutoClear) }
    }
    
    // MARK: - 更新
    var autoCheckUpdate: Bool {
        get { defaults.bool(forKey: Keys.autoCheckUpdate) }
        set { defaults.set(newValue, forKey: Keys.autoCheckUpdate) }
    }
    
    var lastUpdateCheckTime: Double {
        get { defaults.double(forKey: Keys.lastUpdateCheckTime) }
        set { defaults.set(newValue, forKey: Keys.lastUpdateCheckTime) }
    }
    
    // MARK: - 翻译
    var autoTranslateEnabled: Bool {
        get { defaults.bool(forKey: Keys.autoTranslateEnabled) }
        set { defaults.set(newValue, forKey: Keys.autoTranslateEnabled) }
    }
    
    // MARK: - 导入导出
    /// 导出所有设置为 JSON 字符串
    func exportSettings() -> String {
        var dict: [String: Any] = [:]
        dict[Keys.addressBarPosition] = addressBarPosition
        dict[Keys.defaultSearchEngine] = defaultSearchEngine
        dict[Keys.userAgent] = userAgent
        dict[Keys.gestureSensitivity] = gestureSensitivity
        dict[Keys.menuAnimationDuration] = menuAnimationDuration
        dict[Keys.adBlockEnabled] = adBlockEnabled
        dict[Keys.globalImageBlock] = globalImageBlock
        dict[Keys.dnsPrefetchEnabled] = dnsPrefetchEnabled
        dict[Keys.mediaAutoplayBlocked] = mediaAutoplayBlocked
        dict[Keys.backgroundAnimationThrottle] = backgroundAnimationThrottle
        dict[Keys.memoryWarningAutoClear] = memoryWarningAutoClear
        dict[Keys.autoTranslateEnabled] = autoTranslateEnabled
        
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }
    
    /// 从 JSON 字符串导入设置
    func importSettings(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        
        if let v = dict[Keys.addressBarPosition] as? String { addressBarPosition = v }
        if let v = dict[Keys.defaultSearchEngine] as? String { defaultSearchEngine = v }
        if let v = dict[Keys.userAgent] as? String { userAgent = v }
        if let v = dict[Keys.gestureSensitivity] as? Double { gestureSensitivity = v }
        if let v = dict[Keys.menuAnimationDuration] as? Double { menuAnimationDuration = v }
        if let v = dict[Keys.adBlockEnabled] as? Bool { adBlockEnabled = v }
        if let v = dict[Keys.globalImageBlock] as? Bool { globalImageBlock = v }
        if let v = dict[Keys.dnsPrefetchEnabled] as? Bool { dnsPrefetchEnabled = v }
        if let v = dict[Keys.mediaAutoplayBlocked] as? Bool { mediaAutoplayBlocked = v }
        if let v = dict[Keys.backgroundAnimationThrottle] as? Bool { backgroundAnimationThrottle = v }
        if let v = dict[Keys.memoryWarningAutoClear] as? Bool { memoryWarningAutoClear = v }
        if let v = dict[Keys.autoTranslateEnabled] as? Bool { autoTranslateEnabled = v }
        
        return true
    }
    
    /// 重置所有设置为默认值
    func resetAllSettings() {
        defaults.removeObject(forKey: Keys.addressBarPosition)
        defaults.removeObject(forKey: Keys.defaultSearchEngine)
        defaults.removeObject(forKey: Keys.userAgent)
        defaults.removeObject(forKey: Keys.gestureSensitivity)
        defaults.removeObject(forKey: Keys.menuAnimationDuration)
        defaults.removeObject(forKey: Keys.adBlockEnabled)
        defaults.removeObject(forKey: Keys.globalImageBlock)
        defaults.removeObject(forKey: Keys.dnsPrefetchEnabled)
        defaults.removeObject(forKey: Keys.mediaAutoplayBlocked)
        defaults.removeObject(forKey: Keys.backgroundAnimationThrottle)
        defaults.removeObject(forKey: Keys.memoryWarningAutoClear)
        defaults.removeObject(forKey: Keys.autoTranslateEnabled)
    }
    
    // MARK: - 版本检测
    /// 检查 GitHub 仓库最新版本（包含 Draft 草稿 Release）
    func checkForUpdate(repo: String, currentVersion: String, completion: @escaping (Bool, String?) -> Void) {
        DebugLogger.shared.logInfo("版本检测开始：本地版本 v\(currentVersion)，仓库 \(repo)")
        // 使用 /releases?per_page=1 获取所有Release（包含Draft），取最新一个
        // /releases/latest 只返回已发布的Release，不包含Draft
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=1")!
        var request = URLRequest(url: url)
        // 禁用缓存，强制拉取最新数据
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        // GitHub API 要求设置 User-Agent
        request.setValue("LightBrowser-iOS", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DebugLogger.shared.logError("版本检测请求失败：\(error.localizedDescription)")
                DispatchQueue.main.async { completion(false, nil) }
                return
            }
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                DebugLogger.shared.logInfo("版本检测HTTP状态码：\(httpResponse.statusCode)")
                if httpResponse.statusCode == 403 {
                    DebugLogger.shared.logError("版本检测失败：GitHub API速率限制(403)")
                    DispatchQueue.main.async { completion(false, nil) }
                    return
                }
                if httpResponse.statusCode != 200 {
                    DebugLogger.shared.logError("版本检测失败：HTTP状态码 \(httpResponse.statusCode)")
                    DispatchQueue.main.async { completion(false, nil) }
                    return
                }
            }
            guard let data = data,
                  let releases = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let dict = releases.first,
                  let tag = dict["tag_name"] as? String else {
                DebugLogger.shared.logError("版本检测解析失败：无有效Release数据")
                DispatchQueue.main.async { completion(false, nil) }
                return
            }
            let latestVersion = tag.replacingOccurrences(of: "v", with: "")
            // 数字分段版本比较
            let hasUpdate = self.isVersion(latestVersion, greaterThan: currentVersion)
            // 检查是否有IPA附件
            let assets = dict["assets"] as? [[String: Any]] ?? []
            let hasIPA = assets.contains { ($0["name"] as? String)?.lowercased().hasSuffix(".ipa") ?? false }
            let isDraft = dict["draft"] as? Bool ?? false
            DebugLogger.shared.logInfo("版本检测完成：远程 v\(latestVersion)（Draft=\(isDraft)），本地 v\(currentVersion)，有更新=\(hasUpdate)，IPA附件=\(hasIPA)，附件数=\(assets.count)")
            DispatchQueue.main.async { completion(hasUpdate, latestVersion) }
        }.resume()
    }
    
    /// 数字分段版本比较：v1 > v2 返回 true
    private func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(parts1.count, parts2.count)
        for i in 0..<maxLen {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }
}
