import Foundation
import UIKit
import WebKit

// MARK: - 浏览器 AI 集成
class WebAIIntegration: NSObject {
    static let shared = WebAIIntegration()
    
    private override init() {}
    
    // MARK: - 划词 AI 菜单
    func setupSelectionMenu(for webView: WKWebView) {
        // 自定义菜单项
        let translateItem = UIMenuItem(title: "AI翻译", action: #selector(WKWebView.aiTranslateSelection))
        let explainItem = UIMenuItem(title: "AI解释", action: #selector(WKWebView.aiExplainSelection))
        let summarizeItem = UIMenuItem(title: "AI总结", action: #selector(WKWebView.aiSummarizeSelection))
        let polishItem = UIMenuItem(title: "AI润色", action: #selector(WKWebView.aiPolishSelection))
        
        UIMenuController.shared.menuItems = [translateItem, explainItem, summarizeItem, polishItem]
    }
    
    // MARK: - 获取选中文本
    func getSelectedText(from webView: WKWebView, completion: @escaping (String?) -> Void) {
        webView.evaluateJavaScript("window.getSelection().toString()") { result, _ in
            completion(result as? String)
        }
    }
    
    // MARK: - 页面总结
    func summarizePage(from webView: WKWebView, completion: @escaping (String?, Error?) -> Void) {
        // 获取页面主要文本
        let js = """
        (function() {
            var text = '';
            var elements = document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li, article');
            for (var i = 0; i < elements.length; i++) {
                var t = elements[i].innerText.trim();
                if (t.length > 20) text += t + '\\n';
            }
            return text.substring(0, 8000);
        })();
        """
        webView.evaluateJavaScript(js) { result, error in
            guard let pageText = result as? String, !pageText.isEmpty else {
                completion(nil, error ?? NSError(domain: "WebAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取页面内容"]))
                return
            }
            
            // 调用 AI 总结
            guard let config = AIModelManager.shared.currentConfig(), !config.apiKey.isEmpty else {
                completion(nil, NSError(domain: "WebAI", code: -2, userInfo: [NSLocalizedDescriptionKey: "请先配置API Key"]))
                return
            }
            
            let messages = [
                ChatMessage(role: "system", content: "你是一个专业的内容总结助手，请用中文简洁地总结以下网页内容，提取核心要点，分点列出。", timestamp: Date().timeIntervalSince1970),
                ChatMessage(role: "user", content: "请总结以下网页内容：\n\n\(pageText)", timestamp: Date().timeIntervalSince1970)
            ]
            
            AIModelManager.shared.sendChat(messages: messages, config: config, model: AIModelManager.shared.currentModel, params: AIModelManager.shared.loadParams()) { response, error in
                completion(response, error)
            }
        }
    }
    
    // MARK: - 页面问答
    func askAboutPage(from webView: WKWebView, question: String, completion: @escaping (String?, Error?) -> Void) {
        let js = """
        (function() {
            var text = '';
            var elements = document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li, article');
            for (var i = 0; i < elements.length; i++) {
                var t = elements[i].innerText.trim();
                if (t.length > 20) text += t + '\\n';
            }
            return text.substring(0, 8000);
        })();
        """
        webView.evaluateJavaScript(js) { result, error in
            guard let pageText = result as? String else {
                completion(nil, error)
                return
            }
            
            guard let config = AIModelManager.shared.currentConfig(), !config.apiKey.isEmpty else {
                completion(nil, NSError(domain: "WebAI", code: -2, userInfo: [NSLocalizedDescriptionKey: "请先配置API Key"]))
                return
            }
            
            let messages = [
                ChatMessage(role: "system", content: "你是一个网页内容问答助手，请根据提供的网页内容回答用户的问题。如果网页中没有相关信息，请明确说明。", timestamp: Date().timeIntervalSince1970),
                ChatMessage(role: "user", content: "网页内容：\n\(pageText)\n\n问题：\(question)", timestamp: Date().timeIntervalSince1970)
            ]
            
            AIModelManager.shared.sendChat(messages: messages, config: config, model: AIModelManager.shared.currentModel, params: AIModelManager.shared.loadParams()) { response, error in
                completion(response, error)
            }
        }
    }
    
    // MARK: - AI 整页翻译
    func translatePage(from webView: WKWebView, completion: @escaping (Bool, Error?) -> Void) {
        let js = """
        (function() {
            var texts = [];
            var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
                acceptNode: function(node) {
                    if (!node.textContent || !node.textContent.trim()) return NodeFilter.FILTER_REJECT;
                    var p = node.parentElement;
                    if (!p) return NodeFilter.FILTER_REJECT;
                    var t = p.tagName.toLowerCase();
                    if (t==='script'||t==='style'||t==='noscript'||t==='textarea'||t==='input') return NodeFilter.FILTER_REJECT;
                    if (/[\\u4e00-\\u9fa5]/.test(node.textContent)) return NodeFilter.FILTER_REJECT;
                    if (node.textContent.trim().length < 2) return NodeFilter.FILTER_REJECT;
                    return NodeFilter.FILTER_ACCEPT;
                }
            });
            var n;
            while ((n = walker.nextNode())) {
                texts.push(n.textContent.trim());
            }
            return JSON.stringify(texts.slice(0, 200));
        })();
        """
        webView.evaluateJavaScript(js) { result, error in
            guard let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let texts = try? JSONSerialization.jsonObject(with: data) as? [String],
                  !texts.isEmpty else {
                completion(false, error)
                return
            }
            
            guard let config = AIModelManager.shared.currentConfig(), !config.apiKey.isEmpty else {
                completion(false, NSError(domain: "WebAI", code: -2, userInfo: [NSLocalizedDescriptionKey: "请先配置API Key"]))
                return
            }
            
            // 批量翻译（每10条一组）
            let batchSize = 10
            var translatedTexts: [String] = []
            let group = DispatchGroup()
            
            for i in stride(from: 0, to: texts.count, by: batchSize) {
                let batch = Array(texts[i..<min(i + batchSize, texts.count)])
                group.enter()
                
                let messages = [
                    ChatMessage(role: "system", content: "你是一个翻译助手，将以下英文翻译成中文，保持原文格式，每条用|||分隔。", timestamp: Date().timeIntervalSince1970),
                    ChatMessage(role: "user", content: batch.joined(separator: "\n---\n"), timestamp: Date().timeIntervalSince1970)
                ]
                
                AIModelManager.shared.sendChat(messages: messages, config: config, model: AIModelManager.shared.currentModel, params: AIModelManager.shared.loadParams()) { response, _ in
                    if let response = response {
                        translatedTexts.append(contentsOf: response.components(separatedBy: "|||").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                    } else {
                        translatedTexts.append(contentsOf: batch) // 翻译失败保留原文
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                // 将翻译结果注入网页
                let jsonData = try? JSONSerialization.data(withJSONObject: translatedTexts)
                let jsonStr = String(data: jsonData ?? Data(), encoding: .utf8) ?? "[]"
                let injectJS = """
                (function() {
                    var translations = \(jsonStr);
                    var idx = 0;
                    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
                        acceptNode: function(node) {
                            if (!node.textContent || !node.textContent.trim()) return NodeFilter.FILTER_REJECT;
                            var p = node.parentElement;
                            if (!p) return NodeFilter.FILTER_REJECT;
                            var t = p.tagName.toLowerCase();
                            if (t==='script'||t==='style'||t==='noscript'||t==='textarea'||t==='input') return NodeFilter.FILTER_REJECT;
                            if (/[\\u4e00-\\u9fa5]/.test(node.textContent)) return NodeFilter.FILTER_REJECT;
                            if (node.textContent.trim().length < 2) return NodeFilter.FILTER_REJECT;
                            return NodeFilter.FILTER_ACCEPT;
                        }
                    });
                    var n;
                    while ((n = walker.nextNode()) && idx < translations.length) {
                        n.textContent = translations[idx];
                        idx++;
                    }
                    return idx;
                })();
                """
                webView.evaluateJavaScript(injectJS) { _, _ in
                    completion(true, nil)
                }
            }
        }
    }
}

// MARK: - WKWebView 扩展
extension WKWebView {
    @objc func aiTranslateSelection() {
        WebAIIntegration.shared.getSelectedText(from: self) { text in
            guard let text = text, !text.isEmpty else { return }
            // 发送到 AI 对话页面进行翻译
            NotificationCenter.default.post(name: NSNotification.Name("AITranslateSelection"), object: text)
        }
    }
    
    @objc func aiExplainSelection() {
        WebAIIntegration.shared.getSelectedText(from: self) { text in
            guard let text = text, !text.isEmpty else { return }
            NotificationCenter.default.post(name: NSNotification.Name("AIExplainSelection"), object: text)
        }
    }
    
    @objc func aiSummarizeSelection() {
        WebAIIntegration.shared.getSelectedText(from: self) { text in
            guard let text = text, !text.isEmpty else { return }
            NotificationCenter.default.post(name: NSNotification.Name("AISummarizeSelection"), object: text)
        }
    }
    
    @objc func aiPolishSelection() {
        WebAIIntegration.shared.getSelectedText(from: self) { text in
            guard let text = text, !text.isEmpty else { return }
            NotificationCenter.default.post(name: NSNotification.Name("AIPolishSelection"), object: text)
        }
    }
}
