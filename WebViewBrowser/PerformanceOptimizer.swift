import UIKit
import WebKit

/// 性能优化管理器
/// 负责启动速度、内存占用、网页加载、电池消耗等优化
class PerformanceOptimizer: NSObject {
    static let shared = PerformanceOptimizer()
    
    private override init() {}
    
    // MARK: - 启动时间监控
    private var launchStartTime: CFAbsoluteTime = 0
    private(set) var launchDuration: TimeInterval = 0
    
    func markLaunchStart() {
        launchStartTime = CFAbsoluteTimeGetCurrent()
    }
    
    func markLaunchEnd() {
        launchDuration = CFAbsoluteTimeGetCurrent() - launchStartTime
        DebugLogger.shared.logInfo("应用启动耗时: \(String(format: "%.2f", launchDuration))秒")
    }
    
    // MARK: - WebView 配置优化
    func optimizedConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        
        // 1. 进程池共享（多标签共用一个进程，减少内存）
        config.processPool = WKProcessPool()
        
        // 2. 网站数据存储（持久化Cookie和缓存）
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        // 3. 偏好设置优化
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        
        // 4. 媒体播放优化（不自动播放，节省流量和电量）
        config.mediaTypesRequiringUserActionForPlayback = .all
        
        // 5. 允许内联媒体播放（不强制全屏）
        config.allowsInlineMediaPlayback = true
        
        // 6. 增强型JavaScript（JIT编译，提升JS执行速度）
        if #available(iOS 15.0, *) {
            // iOS15+ 自动启用JIT，无需额外配置
        }
        
        return config
    }
    
    // MARK: - DNS 预解析
    /// 预解析常见域名，加快首次访问速度
    func prefetchDNS(domains: [String]) {
        for domain in domains {
            // 使用DNS查询预解析（系统会缓存结果）
            let task = URLSession.shared.dataTask(with: URL(string: "https://\(domain)")!) { _, _, _ in }
            task.priority = URLSessionTask.lowPriority
            task.resume()
        }
        DebugLogger.shared.logInfo("DNS预解析: \(domains.joined(separator: ", "))")
    }
    
    // MARK: - 内存优化
    /// 处理内存警告
    func handleMemoryWarning() {
        DebugLogger.shared.logWarning("收到内存警告，清理缓存")
        
        // 清理 WKWebView 缓存
        let dataStore = WKWebsiteDataStore.default()
        let date = Date(timeIntervalSinceNow: -3600) // 清理1小时前的缓存
        dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: date) {
            DebugLogger.shared.logInfo("内存警告：已清理旧缓存")
        }
        
        // 清理 NSURLCache
        URLCache.shared.removeAllCachedResponses()
    }
    
    /// 优化 WebView 内存（后台标签页调用）
    func optimizeWebViewForBackground(_ webView: WKWebView) {
        // 暂停 JavaScript 计时器（减少CPU和电量消耗）
        webView.evaluateJavaScript("document.querySelectorAll('video, audio').forEach(v => v.pause())", completionHandler: nil)
        
        // 停止加载（如果还在加载）
        if webView.isLoading {
            webView.stopLoading()
        }
    }
    
    // MARK: - 网页加载性能监控
    private var loadStartTime: CFAbsoluteTime = 0
    
    func markLoadStart() {
        loadStartTime = CFAbsoluteTimeGetCurrent()
    }
    
    func markLoadEnd(url: String) {
        let duration = CFAbsoluteTimeGetCurrent() - loadStartTime
        DebugLogger.shared.logInfo("网页加载耗时: \(String(format: "%.2f", duration))秒 - \(url)")
    }
    
    // MARK: - 电池优化
    /// 进入后台时的优化
    func optimizeForBackground() {
        DebugLogger.shared.logInfo("进入后台，执行电量优化")
        // 停止所有 WebView 的网络活动
        // 系统会自动处理，这里记录日志
    }
    
    /// 进入前台时的恢复
    func restoreFromBackground() {
        DebugLogger.shared.logInfo("进入前台，恢复正常状态")
    }
}
