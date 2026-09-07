import UIKit
import WebKit

/// 网页文字查找管理器
/// iOS16+ 优先使用系统原生 findInteraction，iOS14-15 用 JS window.find() 兜底
class FindInPageManager: NSObject {
    static let shared = FindInPageManager()
    
    private override init() {}
    
    /// 当前查找关键词
    private(set) var currentKeyword: String = ""
    /// 当前匹配索引
    private(set) var currentMatchIndex: Int = 0
    /// 总匹配数
    private(set) var totalMatches: Int = 0
    
    // MARK: - iOS16+ 原生查找
    
    /// 显示系统原生查找导航器（iOS16+）
    @available(iOS 16.0, *)
    func presentNativeFindNavigator(in webView: WKWebView, initialText: String = "") {
        guard let interaction = webView.findInteraction else {
            // fallback 到 JS 方案
            return
        }
        interaction.presentFindNavigator(showingReplace: false)
        // 系统查找栏会自动处理，不需要额外操作
    }
    
    // MARK: - iOS14-15 JS 兜底查找
    
    /// 执行查找并高亮（JS方案）
    func findInWebView(_ webView: WKWebView, keyword: String, completion: @escaping (Int, Int) -> Void) {
        guard !keyword.isEmpty else {
            clearHighlights(in: webView)
            currentKeyword = ""
            totalMatches = 0
            currentMatchIndex = 0
            completion(0, 0)
            return
        }
        
        currentKeyword = keyword
        
        // 注入查找JS
        let js = """
        (function() {
            // 清除旧高亮
            document.querySelectorAll('mark.__browser_find__').forEach(function(el) {
                var parent = el.parentNode;
                while (el.firstChild) parent.insertBefore(el.firstChild, el);
                parent.removeChild(el);
                parent.normalize();
            });
            
            var keyword = \(keyword.replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n"));
            if (!keyword) return JSON.stringify({count: 0});
            
            var count = 0;
            var escaped = keyword.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');
            var regex = new RegExp(escaped, 'gi');
            
            // 遍历所有文本节点（含代码块pre/code内）
            function walkNodes(node) {
                if (node.nodeType === 3) {
                    var text = node.textContent;
                    regex.lastIndex = 0;
                    if (regex.test(text) && node.parentElement && 
                        !node.parentElement.closest('script,style,textarea,mark.__browser_find__')) {
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
                            mark.dataset.index = count;
                            fragment.appendChild(mark);
                            count++;
                            lastIndex = regex.lastIndex;
                        }
                        if (lastIndex < text.length) {
                            fragment.appendChild(document.createTextNode(text.slice(lastIndex)));
                        }
                        node.parentNode.replaceChild(fragment, node);
                    }
                } else if (node.nodeType === 1 && node.tagName !== 'SCRIPT' && node.tagName !== 'STYLE') {
                    for (var i = node.childNodes.length - 1; i >= 0; i--) {
                        walkNodes(node.childNodes[i]);
                    }
                }
            }
            walkNodes(document.body);
            
            // 添加高亮样式
            if (!document.getElementById('__browser_find_style__')) {
                var style = document.createElement('style');
                style.id = '__browser_find_style__';
                style.textContent = 'mark.__browser_find__{background:#ffeb3b!important;color:inherit!important;padding:0!important;border-radius:2px}mark.__browser_find__.active{background:#ff9800!important;outline:2px solid #f57c00!important}';
                document.head.appendChild(style);
            }
            
            return JSON.stringify({count: count});
        })();
        """
        
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self else { return }
            if let jsonStr = result as? String,
               let data = jsonStr.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let count = dict["count"] as? Int {
                self.totalMatches = count
                self.currentMatchIndex = count > 0 ? 1 : 0
                if count > 0 {
                    self.highlightCurrentMatch(in: webView)
                }
                completion(self.currentMatchIndex, count)
            } else {
                completion(0, 0)
            }
        }
    }
    
    /// 高亮当前匹配项并滚动到可视区域
    private func highlightCurrentMatch(in webView: WKWebView) {
        let js = """
        (function() {
            var marks = document.querySelectorAll('mark.__browser_find__');
            if (marks.length === 0) return;
            marks.forEach(function(m) { m.classList.remove('active'); });
            var idx = \(currentMatchIndex - 1);
            if (idx >= 0 && idx < marks.length) {
                marks[idx].classList.add('active');
                marks[idx].scrollIntoView({behavior:'smooth', block:'center'});
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    /// 下一个匹配项
    func findNext(in webView: WKWebView, completion: @escaping (Int, Int) -> Void) {
        guard totalMatches > 0 else {
            completion(0, 0)
            return
        }
        currentMatchIndex += 1
        if currentMatchIndex > totalMatches {
            currentMatchIndex = 1
        }
        highlightCurrentMatch(in: webView)
        completion(currentMatchIndex, totalMatches)
    }
    
    /// 上一个匹配项
    func findPrev(in webView: WKWebView, completion: @escaping (Int, Int) -> Void) {
        guard totalMatches > 0 else {
            completion(0, 0)
            return
        }
        currentMatchIndex -= 1
        if currentMatchIndex < 1 {
            currentMatchIndex = totalMatches
        }
        highlightCurrentMatch(in: webView)
        completion(currentMatchIndex, totalMatches)
    }
    
    /// 清除所有高亮
    func clearHighlights(in webView: WKWebView) {
        let js = """
        (function() {
            document.querySelectorAll('mark.__browser_find__').forEach(function(el) {
                var parent = el.parentNode;
                while (el.firstChild) parent.insertBefore(el.firstChild, el);
                parent.removeChild(el);
                parent.normalize();
            });
            var style = document.getElementById('__browser_find_style__');
            if (style) style.remove();
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
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
