import UIKit

// MARK: - Markdown 渲染器
class MarkdownRenderer {
    
    /// 将 Markdown 文本转为 NSAttributedString
    static func render(_ markdown: String, fontSize: CGFloat = 15) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeLanguage = ""
        var inTable = false
        var tableRows: [[String]] = []
        
        for line in lines {
            // 代码块开始/结束
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // 结束代码块
                    result.append(renderCodeBlock(codeBlockContent, language: codeLanguage, fontSize: fontSize))
                    result.append(NSAttributedString(string: "\n"))
                    codeBlockContent = ""
                    codeLanguage = ""
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                    codeLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            
            if inCodeBlock {
                codeBlockContent += line + "\n"
                continue
            }
            
            // 表格检测
            if line.contains("|") && line.hasPrefix("|") {
                let cells = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                // 跳过分隔行
                if cells.allSatisfy({ $0.contains("---") || $0.contains(":--") }) {
                    continue
                }
                tableRows.append(cells)
                inTable = true
                continue
            } else if inTable && !tableRows.isEmpty {
                // 表格结束
                result.append(renderTable(tableRows, fontSize: fontSize))
                result.append(NSAttributedString(string: "\n"))
                tableRows = []
                inTable = false
            }
            
            result.append(renderInline(line, fontSize: fontSize))
            result.append(NSAttributedString(string: "\n"))
        }
        
        // 处理末尾未闭合的代码块
        if inCodeBlock && !codeBlockContent.isEmpty {
            result.append(renderCodeBlock(codeBlockContent, language: codeLanguage, fontSize: fontSize))
        }
        // 处理末尾表格
        if inTable && !tableRows.isEmpty {
            result.append(renderTable(tableRows, fontSize: fontSize))
        }
        
        return result
    }
    
    /// 渲染行内格式（加粗、斜体、代码、链接）
    private static func renderInline(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: result.length)
        
        // 默认字体
        result.addAttribute(.font, value: UIFont.systemFont(ofSize: fontSize), range: fullRange)
        result.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
        
        // 标题
        if text.hasPrefix("### ") {
            result.replaceCharacters(in: NSRange(location: 0, length: 4), with: "")
            result.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize + 2), range: NSRange(location: 0, length: result.length))
        } else if text.hasPrefix("## ") {
            result.replaceCharacters(in: NSRange(location: 0, length: 3), with: "")
            result.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize + 4), range: NSRange(location: 0, length: result.length))
        } else if text.hasPrefix("# ") {
            result.replaceCharacters(in: NSRange(location: 0, length: 2), with: "")
            result.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize + 6), range: NSRange(location: 0, length: result.length))
        }
        
        // 引用块
        if text.hasPrefix("> ") {
            result.replaceCharacters(in: NSRange(location: 0, length: 2), with: "")
            result.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: NSRange(location: 0, length: result.length))
            result.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: fontSize), range: NSRange(location: 0, length: result.length))
        }
        
        // 无序列表
        if text.hasPrefix("- ") || text.hasPrefix("* ") {
            result.replaceCharacters(in: NSRange(location: 0, length: 2), with: "• ")
        }
        
        // 行内代码 `code`
        if let regex = try? NSRegularExpression(pattern: "`([^`]+)`", options: []) {
            let matches = regex.matches(in: result.string, options: [], range: fullRange)
            for match in matches.reversed() {
                let codeRange = match.range(at: 1)
                if let code = result.attributedSubstring(from: codeRange).string as NSString? {
                    let codeAttr = NSMutableAttributedString(string: code as String)
                    codeAttr.addAttribute(.font, value: UIFont(name: "Menlo", size: fontSize - 1) ?? UIFont.systemFont(ofSize: fontSize - 1), range: NSRange(location: 0, length: code.length))
                    codeAttr.addAttribute(.backgroundColor, value: UIColor.secondarySystemBackground, range: NSRange(location: 0, length: code.length))
                    codeAttr.addAttribute(.foregroundColor, value: UIColor.systemRed, range: NSRange(location: 0, length: code.length))
                    result.replaceCharacters(in: match.range, with: codeAttr)
                }
            }
        }
        
        // 加粗 **text**
        if let regex = try? NSRegularExpression(pattern: "\\*\\*([^*]+)\\*\\*", options: []) {
            let matches = regex.matches(in: result.string, options: [], range: NSRange(location: 0, length: result.length))
            for match in matches.reversed() {
                let contentRange = match.range(at: 1)
                result.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize), range: contentRange)
                result.replaceCharacters(in: match.range, with: result.attributedSubstring(from: contentRange))
            }
        }
        
        // 斜体 *text*
        if let regex = try? NSRegularExpression(pattern: "(?<!\\*)\\*([^*]+)\\*(?!\\*)", options: []) {
            let matches = regex.matches(in: result.string, options: [], range: NSRange(location: 0, length: result.length))
            for match in matches.reversed() {
                let contentRange = match.range(at: 1)
                result.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: fontSize), range: contentRange)
                result.replaceCharacters(in: match.range, with: result.attributedSubstring(from: contentRange))
            }
        }
        
        // 链接 [text](url)
        if let regex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)", options: []) {
            let matches = regex.matches(in: result.string, options: [], range: NSRange(location: 0, length: result.length))
            for match in matches.reversed() {
                let textRange = match.range(at: 1)
                let urlRange = match.range(at: 2)
                if let urlStr = result.attributedSubstring(from: urlRange).string as NSString?,
                   let url = URL(string: urlStr as String) {
                    let linkAttr = NSMutableAttributedString(attributedString: result.attributedSubstring(from: textRange))
                    linkAttr.addAttribute(.link, value: url, range: NSRange(location: 0, length: linkAttr.length))
                    linkAttr.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: NSRange(location: 0, length: linkAttr.length))
                    result.replaceCharacters(in: match.range, with: linkAttr)
                }
            }
        }
        
        return result
    }
    
    /// 渲染代码块
    private static func renderCodeBlock(_ code: String, language: String, fontSize: CGFloat) -> NSAttributedString {
        let trimmed = code.trimmingCharacters(in: .newlines)
        let result = NSMutableAttributedString(string: trimmed)
        let range = NSRange(location: 0, length: result.length)
        
        result.addAttribute(.font, value: UIFont(name: "Menlo", size: fontSize - 1) ?? UIFont.systemFont(ofSize: fontSize - 1), range: range)
        result.addAttribute(.foregroundColor, value: UIColor.label, range: range)
        result.addAttribute(.backgroundColor, value: UIColor.secondarySystemBackground, range: range)
        
        // 简单语法高亮
        let keywords = ["func", "class", "struct", "enum", "let", "var", "if", "else", "for", "while", "return", "import", "func", "static", "private", "public", "internal", "guard", "switch", "case", "default", "break", "continue", "throw", "try", "catch", "do", "extension", "protocol", "typealias", "init", "deinit", "subscript", "inout", "where", "associatedtype", "in", "of", "as", "is", "super", "self", "nil", "true", "false", "void", "int", "string", "double", "float", "bool", "any", "some"]
        
        for keyword in keywords {
            if let regex = try? NSRegularExpression(pattern: "\\b\(keyword)\\b", options: []) {
                let matches = regex.matches(in: result.string, options: [], range: range)
                for match in matches {
                    result.addAttribute(.foregroundColor, value: UIColor.systemPink, range: match.range)
                }
            }
        }
        
        // 字符串高亮
        if let regex = try? NSRegularExpression(pattern: "\"[^\"]*\"", options: []) {
            let matches = regex.matches(in: result.string, options: [], range: range)
            for match in matches {
                result.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: match.range)
            }
        }
        
        // 注释高亮
        if let regex = try? NSRegularExpression(pattern: "//.*$", options: [.anchorsMatchLines]) {
            let matches = regex.matches(in: result.string, options: [], range: range)
            for match in matches {
                result.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: match.range)
            }
        }
        
        return result
    }
    
    /// 渲染表格
    private static func renderTable(_ rows: [[String]], fontSize: CGFloat) -> NSAttributedString {
        var text = ""
        for (index, row) in rows.enumerated() {
            if index == 0 {
                text += "📊 " + row.joined(separator: " | ") + "\n"
            } else {
                text += "   " + row.joined(separator: " | ") + "\n"
            }
        }
        let result = NSMutableAttributedString(string: text)
        result.addAttribute(.font, value: UIFont(name: "Menlo", size: fontSize - 1) ?? UIFont.systemFont(ofSize: fontSize - 1), range: NSRange(location: 0, length: result.length))
        result.addAttribute(.backgroundColor, value: UIColor.secondarySystemBackground, range: NSRange(location: 0, length: result.length))
        return result
    }
    
    /// 提取代码块内容（用于复制）
    static func extractCodeBlocks(from markdown: String) -> [String] {
        var codeBlocks: [String] = []
        let pattern = "```[\\s\\S]*?```"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: markdown, options: [], range: NSRange(location: 0, length: markdown.utf16.count))
            for match in matches {
                if let range = Range(match.range, in: markdown) {
                    var code = String(markdown[range])
                    code = code.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
                    code = code.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
                    codeBlocks.append(code.trimmingCharacters(in: .newlines))
                }
            }
        }
        return codeBlocks
    }
}
