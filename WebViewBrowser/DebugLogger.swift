import UIKit

/// 全局调试日志管理器
/// - 自动记录崩溃日志
/// - 手动记录普通日志
/// - 支持复制、删除、分享
class DebugLogger: NSObject {
    static let shared = DebugLogger()
    
    private let logFileName = "debug_log.txt"
    private let maxLogSize: Int64 = 2 * 1024 * 1024 // 最大2MB，超过自动截断
    
    private var logFileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(logFileName)
    }
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return df
    }()
    
    private override init() {
        super.init()
        setupCrashHandler()
    }
    
    // MARK: - 崩溃捕获
    
    private func setupCrashHandler() {
        // 捕获 Objective-C 异常
        NSSetUncaughtExceptionHandler { exception in
            DebugLogger.shared.logCrash(exception: exception)
        }
        
        // 捕获 Unix 信号崩溃
        signal(SIGABRT) { sig in DebugLogger.shared.logSignalCrash(signal: sig) }
        signal(SIGILL) { sig in DebugLogger.shared.logSignalCrash(signal: sig) }
        signal(SIGSEGV) { sig in DebugLogger.shared.logSignalCrash(signal: sig) }
        signal(SIGFPE) { sig in DebugLogger.shared.logSignalCrash(signal: sig) }
        signal(SIGBUS) { sig in DebugLogger.shared.logSignalCrash(signal: sig) }
        signal(SIGPIPE) { sig in DebugLogger.shared.logSignalCrash(signal: sig) }
    }
    
    private func logCrash(exception: NSException) {
        let stackSymbols = exception.callStackSymbols.joined(separator: "\n")
        let log = """
        
        ====== 崩溃日志 (NSException) ======
        时间: \(dateFormatter.string(from: Date()))
        异常名: \(exception.name.rawValue)
        原因: \(exception.reason ?? "未知")
        调用栈:
        \(stackSymbols)
        ====================================
        
        """
        writeToFile(log)
    }
    
    private func logSignalCrash(signal: Int32) {
        let signalName = signalName(signal)
        let stack = Thread.callStackSymbols.joined(separator: "\n")
        let log = """
        
        ====== 崩溃日志 (Signal: \(signalName)) ======
        时间: \(dateFormatter.string(from: Date()))
        信号: \(signal) (\(signalName))
        调用栈:
        \(stack)
        ====================================
        
        """
        writeToFile(log)
    }
    
    private func signalName(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT"
        case SIGILL: return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGFPE: return "SIGFPE"
        case SIGBUS: return "SIGBUS"
        case SIGPIPE: return "SIGPIPE"
        default: return "UNKNOWN"
        }
    }
    
    // MARK: - 手动日志
    
    func logInfo(_ message: String) {
        writeLog(level: "INFO", message: message)
    }
    
    func logWarning(_ message: String) {
        writeLog(level: "WARNING", message: message)
    }
    
    func logError(_ message: String) {
        writeLog(level: "ERROR", message: message)
    }
    
    private func writeLog(level: String, message: String) {
        let log = "[\(dateFormatter.string(from: Date()))] [\(level)] \(message)\n"
        writeToFile(log)
    }
    
    // MARK: - 文件操作
    
    private func writeToFile(_ content: String) {
        DispatchQueue.global(qos: .utility).async {
            do {
                // 检查文件大小，超过限制则截断保留后半部分
                if let attrs = try? FileManager.default.attributesOfItem(atPath: self.logFileURL.path),
                   let size = attrs[.size] as? Int64,
                   size > self.maxLogSize {
                    self.truncateLogFile()
                }
                
                if let data = content.data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                        let fileHandle = try FileHandle(forWritingTo: self.logFileURL)
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    } else {
                        try data.write(to: self.logFileURL)
                    }
                }
            } catch {
                print("DebugLogger write error: \(error)")
            }
        }
    }
    
    private func truncateLogFile() {
        do {
            let content = try String(contentsOf: logFileURL, encoding: .utf8)
            // 保留后半部分（最新的日志）
            let lines = content.components(separatedBy: "\n")
            let keepCount = max(lines.count / 2, 100)
            let kept = lines.suffix(keepCount).joined(separator: "\n")
            try kept.write(to: logFileURL, atomically: true, encoding: .utf8)
        } catch {
            print("DebugLogger truncate error: \(error)")
        }
    }
    
    /// 读取全部日志
    func readLog() -> String {
        do {
            return try String(contentsOf: logFileURL, encoding: .utf8)
        } catch {
            return "暂无日志"
        }
    }
    
    /// 清空日志
    func clearLog() {
        do {
            try "".write(to: logFileURL, atomically: true, encoding: .utf8)
        } catch {
            print("DebugLogger clear error: \(error)")
        }
    }
    
    /// 复制日志到剪贴板
    func copyLog() {
        UIPasteboard.general.string = readLog()
    }
    
    /// 获取日志文件路径（用于分享）
    func logFilePath() -> URL {
        return logFileURL
    }
    
    /// 日志大小
    func logSize() -> String {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: logFileURL.path)
            if let size = attrs[.size] as? Int64 {
                if size < 1024 {
                    return "\(size) B"
                } else if size < 1024 * 1024 {
                    return String(format: "%.1f KB", Double(size) / 1024.0)
                } else {
                    return String(format: "%.2f MB", Double(size) / (1024.0 * 1024.0))
                }
            }
        } catch {}
        return "0 B"
    }
}
