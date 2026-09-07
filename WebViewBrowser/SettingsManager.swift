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
            Keys.autoTranslateEnabled: false
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
    /// 检查 GitHub 仓库最新版本
    func checkForUpdate(repo: String, currentVersion: String, completion: @escaping (Bool, String?) -> Void) {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = dict["tag_name"] as? String else {
                DispatchQueue.main.async { completion(false, nil) }
                return
            }
            let latestVersion = tag.replacingOccurrences(of: "v", with: "")
            let hasUpdate = latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending
            DispatchQueue.main.async { completion(hasUpdate, latestVersion) }
        }.resume()
    }
}
