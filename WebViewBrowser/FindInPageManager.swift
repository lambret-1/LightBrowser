import UIKit
import WebKit

/// 网页文字查找管理器
/// 使用 JS TreeWalker 遍历所有文本节点（含代码块），<mark>标签高亮
class FindInPageManager: NSObject {
    static let shared = FindInPageManager()
    
    private override init() {}
    
    /// 当前查找关键词
    private(set) var currentKeyword: String = ""
    /// 当前匹配索引
    private(set) var currentMatchIndex: Int = 0
    /// 总匹配数
    private(set) var totalMatches: Int = 0
    
    // MARK: - JS 查找高亮
    
    /// 执行查找并高亮（JS方案）
    func findInWebView(_ webView: WKWebView, keyword: String, completion: @escaping (Int, Int) -> Void) {
        guard !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearHighlights(in: webView)
            completion(0, 0)
            return
        }
        
        currentKeyword = keyword
        
        // 安全转义关键词为 JS 字符串字面量
        let escapedKeyword = keyword
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        let keywordLiteral = "\"\(escapedKeyword)\""
        
        let js = """
        (function() {
            // 1. 清除旧高亮
            var oldMarks = document.querySelectorAll('mark.__browser_find__');
            oldMarks.forEach(function(el) {
                var parent = el.parentNode;
                while (el.firstChild) parent.insertBefore(el.firstChild, el);
                parent.removeChild(el);
            });
            // 合并相邻文本节点
            document.querySelectorAll('body *').forEach(function(el) {
                if (el.tagName !== 'SCRIPT' && el.tagName !== 'STYLE') {
                    el.normalize();
                }
            });
            
            // 2. 关键词
            var keyword = \(keywordLiteral);
            if (!keyword || !keyword.trim()) return JSON.stringify({count: 0});
            
            // 3. 正则转义
            var escaped = keyword.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');
            var regex = new RegExp(escaped, 'gi');
            
            // 4. 用 TreeWalker 遍历所有文本节点
            var count = 0;
            var walker = document.createTreeWalker(
                document.body,
                NodeFilter.SHOW_TEXT,
                {
                    acceptNode: function(node) {
                        if (!node.textContent || !node.textContent.trim()) return NodeFilter.FILTER_REJECT;
                        var parent = node.parentElement;
                        if (!parent) return NodeFilter.FILTER_REJECT;
                        if (parent.closest('script,style,textarea,mark.__browser_find__')) return NodeFilter.FILTER_REJECT;
                        return NodeFilter.FILTER_ACCEPT;
                    }
                }
            );
            
            var textNodes = [];
            var node;
            while (node = walker.nextNode()) {
                textNodes.push(node);
            }
            
            // 5. 处理每个文本节点
            textNodes.forEach(function(textNode) {
                var text = textNode.textContent;
                regex.lastIndex = 0;
                if (!regex.test(text)) return;
                
                var fragment = document.createDocumentFragment();
                var lastIndex = 0;
                regex.lastIndex = 0;
                var match;
                
                while ((match = regex.exec(text)) !== null) {
                    if (match.index > lastIndex) {
                        fragment.appendChild(document.createTextNode(text.slice(lastIndex, match.index)));
                    }
                    var mark = document.createElement('mark');
                    mark.className = '__browser_find__';
                    mark.textContent = match[0];
                    mark.dataset.findIndex = count;
                    fragment.appendChild(mark);
                    count++;
                    lastIndex = regex.lastIndex;
                    // 防止空匹配导致无限循环
                    if (match.index === regex.lastIndex) regex.lastIndex++;
                }
                if (lastIndex < text.length) {
                    fragment.appendChild(document.createTextNode(text.slice(lastIndex)));
                }
                textNode.parentNode.replaceChild(fragment, textNode);
            });
            
            // 6. 添加高亮样式
            if (!document.getElementById('__browser_find_style__')) {
                var style = document.createElement('style');
                style.id = '__browser_find_style__';
                style.textContent = 'mark.__browser_find__{background:#ffeb3b!important;color:inherit!important;padding:0 1px!important;border-radius:2px}mark.__browser_find__.active{background:#ff9800!important;outline:2px solid #f57c00!important}';
                document.head.appendChild(style);
            }
            
            return JSON.stringify({count: count});
        })();
        """
        
        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                print("FindInPage JS error: \(error.localizedDescription)")
                completion(0, 0)
                return
            }
            if let jsonStr = result as? String,
               let data = jsonStr.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let count = dict["count"] as? Int {
                self.totalMatches = count
                self.currentMatchIndex = count > 0 ? 1 : 0
                if count > 0 {
                    self.jumpToMatch(in: webView)
                }
                completion(self.currentMatchIndex, count)
            } else {
                completion(0, 0)
            }
        }
    }
    
    /// 下一个匹配项（单次JS调用：切换高亮+滚动）
    func findNext(in webView: WKWebView, completion: @escaping (Int, Int) -> Void) {
        guard totalMatches > 0 else {
            completion(0, 0)
            return
        }
        currentMatchIndex += 1
        if currentMatchIndex > totalMatches {
            currentMatchIndex = 1
        }
        jumpToMatch(in: webView)
        completion(currentMatchIndex, totalMatches)
    }
    
    /// 上一个匹配项（单次JS调用：切换高亮+滚动）
    func findPrev(in webView: WKWebView, completion: @escaping (Int, Int) -> Void) {
        guard totalMatches > 0 else {
            completion(0, 0)
            return
        }
        currentMatchIndex -= 1
        if currentMatchIndex < 1 {
            currentMatchIndex = totalMatches
        }
        jumpToMatch(in: webView)
        completion(currentMatchIndex, totalMatches)
    }
    
    /// 单次JS调用：切换高亮+瞬间滚动到可视区域
    private func jumpToMatch(in webView: WKWebView) {
        let js = """
        (function() {
            var marks = document.querySelectorAll('mark.__browser_find__');
            if (marks.length === 0) return;
            marks.forEach(function(m) { m.classList.remove('active'); });
            var idx = \(currentMatchIndex - 1);
            if (idx >= 0 && idx < marks.length) {
                marks[idx].classList.add('active');
                // 瞬间滚动，无动画
                var rect = marks[idx].getBoundingClientRect();
                window.scrollTo(0, window.scrollY + rect.top - window.innerHeight / 2);
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    /// 清除所有高亮
    func clearHighlights(in webView: WKWebView) {
        let js = """
        (function() {
            // 移除所有高亮mark标签，恢复原始文本
            var marks = document.querySelectorAll('mark.__browser_find__');
            marks.forEach(function(el) {
                var parent = el.parentNode;
                if (!parent) return;
                // 把mark的子节点移到父节点
                while (el.firstChild) {
                    parent.insertBefore(el.firstChild, el);
                }
                parent.removeChild(el);
            });
            // 合并相邻文本节点
            if (document.body) document.body.normalize();
            // 移除样式
            var style = document.getElementById('__browser_find_style__');
            if (style) style.remove();
            return marks.length;
        })();
        """
        webView.evaluateJavaScript(js) { result, error in
            if let error = error {
                print("clearHighlights error: \(error.localizedDescription)")
            }
        }
        currentKeyword = ""
        totalMatches = 0
        currentMatchIndex = 0
    }
    
    /// 获取当前选中文字
    func getSelectedText(in webView: WKWebView, completion: @escaping (String) -> Void) {
        webView.evaluateJavaScript("window.getSelection().toString()") { result, _ in
            completion((result as? String) ?? "")
        }
    }
}
