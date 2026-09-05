//
//  TranslateManager.swift
//  轻量浏览器 - v16.11.1 高性能翻译引擎
//
//  v16.11.1 修复翻译失败：
//  - 优化词典结构：单词(3827) + 短语(5000) 分离
//  - 单词用字典O(1)查找，短语用正则匹配
//  - 分批处理节点，避免主线程阻塞
//  - 修复19000条逐条正则导致的超时问题
//

import UIKit
import WebKit

class TranslateManager {

    static let shared = TranslateManager()

    // MARK: - 词典
    private var wordDictionary: [String: String] = [:]    // 单词词典（O(1)查找）
    private var phraseDictionary: [String: String] = [:]  // 短语词典（正则匹配）
    private var regexRules: [[String: String]] = []       // 正则翻译规则
    private var isDictLoaded = false

    // 内置兜底高频词条
    private let fallbackWords: [String: String] = [
        "home": "首页", "back": "返回", "forward": "前进", "refresh": "刷新",
        "search": "搜索", "submit": "提交", "cancel": "取消", "save": "保存",
        "delete": "删除", "edit": "编辑", "add": "添加", "close": "关闭",
        "open": "打开", "download": "下载", "upload": "上传", "login": "登录",
        "logout": "退出", "register": "注册", "next": "下一步", "continue": "继续",
        "confirm": "确认", "settings": "设置", "help": "帮助", "about": "关于",
        "menu": "菜单", "profile": "资料", "notification": "通知", "message": "消息",
        "favorite": "收藏", "history": "历史", "loading": "加载中", "success": "成功",
        "error": "错误", "warning": "警告", "failed": "失败", "completed": "完成",
        "pending": "待处理", "update": "更新", "create": "创建", "send": "发送",
        "share": "分享", "copy": "复制", "paste": "粘贴", "cut": "剪切",
        "repository": "仓库", "star": "星标", "fork": "复刻", "commit": "提交",
        "issue": "议题", "release": "发布", "branch": "分支", "clone": "克隆",
        "watch": "关注", "code": "代码", "actions": "工作流", "wiki": "维基",
        "discussion": "讨论", "explore": "探索", "trending": "趋势", "docs": "文档",
        "support": "支持", "new": "新建", "file": "文件", "folder": "文件夹",
        "name": "名称", "description": "描述", "public": "公开", "private": "私有",
        "readme": "说明", "license": "许可", "language": "语言", "topics": "主题",
        "sign": "登录", "ok": "确定", "yes": "是", "no": "否"
    ]

    private let fallbackPhrases: [String: String] = [
        "sign in": "登录", "sign up": "注册", "sign out": "退出",
        "pull request": "合并请求", "code review": "代码审查",
        "merge request": "合并请求", "open source": "开源",
        "version control": "版本控制", "source code": "源代码",
        "web hook": "Web钩子", "access token": "访问令牌",
        "two factor": "双因素", "personal access": "个人访问"
    ]

    // MARK: - 翻译模式
    enum TranslateMode: String {
        case local = "local"
        case online = "online"
        case mixed = "mixed"
        case alwaysOn = "alwaysOn"
        case autoEnhanced = "autoEnhanced"
    }

    var currentMode: TranslateMode {
        let mode = UserDefaults.standard.string(forKey: "translateMode") ?? "mixed"
        return TranslateMode(rawValue: mode) ?? .mixed
    }

    func setMode(_ mode: TranslateMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: "translateMode")
    }

    var isAutoTranslateEnabled: Bool {
        return currentMode == .alwaysOn || currentMode == .autoEnhanced
    }

    var isOnlineFallbackEnabled: Bool {
        return currentMode == .autoEnhanced
    }

    // MARK: - 未翻译词条采集
    var isCollectingUntranslated = false
    private var untranslatedWords: Set<String> = []

    func startCollectingUntranslated() {
        isCollectingUntranslated = true
        untranslatedWords.removeAll()
    }

    func stopCollectingUntranslated() -> [String] {
        isCollectingUntranslated = false
        return Array(untranslatedWords).sorted()
    }

    // MARK: - 加载词典
    func loadAllDictionaries() {
        if isDictLoaded && !wordDictionary.isEmpty {
            return
        }

        // 加载优化后的统一词典
        if let path = Bundle.main.path(forResource: "translate_dict", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            wordDictionary = dict["words"] as? [String: String] ?? [:]
            phraseDictionary = dict["phrases"] as? [String: String] ?? [:]
            print("[TranslateManager] 优化词典加载: 单词\(wordDictionary.count) + 短语\(phraseDictionary.count)")
        } else {
            print("[TranslateManager] 优化词典加载失败，使用兜底")
            wordDictionary = fallbackWords
            phraseDictionary = fallbackPhrases
        }

        // 加载正则规则
        regexRules = loadRegexRules(named: "github_regex")
        print("[TranslateManager] 正则规则: \(regexRules.count)条")

        isDictLoaded = true
    }

    private func loadRegexRules(named name: String) -> [[String: String]] {
        guard let path = Bundle.main.path(forResource: name, ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rules = dict["rules"] as? [[String: String]] else {
            return []
        }
        return rules
    }

    func isGithubSite(url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host.contains("github.com") || host.contains("githubusercontent.com") || host.contains("github.io")
    }

    // MARK: - 词典注入脚本（用于WKUserScript，页面加载时注入到window全局变量）
    func dictionaryInjectionScript() -> String {
        loadAllDictionaries()
        guard let wordData = try? JSONSerialization.data(withJSONObject: wordDictionary),
              let wordString = String(data: wordData, encoding: .utf8),
              let phraseData = try? JSONSerialization.data(withJSONObject: phraseDictionary),
              let phraseString = String(data: phraseData, encoding: .utf8),
              let regexData = try? JSONSerialization.data(withJSONObject: regexRules),
              let regexString = String(data: regexData, encoding: .utf8) else {
            return ""
        }
        // 注入到window全局变量，翻译脚本只引用不嵌入，避免大脚本超时
        return """
        (function() {
            try {
                window.__translate_words__ = \(wordString);
                window.__translate_phrases__ = \(phraseString);
                window.__translate_regex__ = \(regexString);
                window.__translate_dict_loaded__ = true;
            } catch(e) {
                window.__translate_dict_loaded__ = false;
            }
        })();
        """
    }

    // MARK: - 生成高性能JS翻译脚本（引用window全局变量，不嵌入词典）
    private func generateTranslateScript(collectUntranslated: Bool = false) -> String {

        let script = """
        (function() {
            try {
                if (window.__browser_translated__) {
                    return {success: true, already: true, translated: 0};
                }
                if (!document.body) return {success: false, reason: 'no_body'};
                if (document.readyState === 'loading') return {success: false, reason: 'page_loading'};

                // v16.11.2 引用window全局变量（由WKUserScript注入），避免大脚本超时
                if (!window.__translate_dict_loaded__) {
                    return {success: false, reason: 'dict_not_loaded'};
                }
                const words = window.__translate_words__ || {};
                const phrases = window.__translate_phrases__ || {};
                const phraseKeys = Object.keys(phrases);
                const regexRules = window.__translate_regex__ || [];
                const translateCache = {};
                const untranslatedSet = new Set();

                const skipTags = {'SCRIPT':1,'STYLE':1,'NOSCRIPT':1,'SVG':1,'CODE':1,'PRE':1,'TEXTAREA':1,'INPUT':1,'SELECT':1,'OPTION':1,'IFRAME':1,'CANVAS':1,'TEMPLATE':1};
                const skipClasses = ['blob-code','CodeMirror','diff-chunk','cm-content','cm-scroller','react-code-text'];
                const MAX_NODES = 3000;
                const BATCH_SIZE = 150;

                let translatedCount = 0;
                let observer = null;
                let pendingNodes = [];
                let debounceTimer = null;

                function isInBlacklist(node) {
                    if (!node || node.nodeType !== 1) return false;
                    if (skipTags[node.tagName]) return true;
                    if (node.className && typeof node.className === 'string') {
                        for (let cls of skipClasses) {
                            if (node.className.includes(cls)) return true;
                        }
                    }
                    let p = node.parentElement;
                    while (p) {
                        if (skipTags[p.tagName]) return true;
                        if (p.className && typeof p.className === 'string') {
                            for (let cls of skipClasses) {
                                if (p.className.includes(cls)) return true;
                            }
                        }
                        p = p.parentElement;
                    }
                    return false;
                }

                // 正则翻译（相对时间、数量）
                function translateByRegex(text) {
                    for (let i = 0; i < regexRules.length; i++) {
                        try {
                            const rule = regexRules[i];
                            const pattern = new RegExp(rule.pattern, 'gi');
                            if (pattern.test(text)) {
                                return text.replace(pattern, rule.replacement);
                            }
                        } catch(e) {}
                    }
                    return null;
                }

                // 单词翻译（O(1)字典查找）
                function translateWords(text) {
                    return text.replace(/\\b[a-zA-Z][a-zA-Z\\-']+\\b/g, function(match) {
                        const lower = match.toLowerCase();
                        if (words[lower]) {
                            // 保持首字母大写
                            if (match[0] === match[0].toUpperCase() && match[0] !== match[0].toLowerCase()) {
                                const t = words[lower];
                                return t.charAt(0).toUpperCase() + t.slice(1);
                            }
                            return words[lower];
                        }
                        // 词形归一化
                        if (lower.endsWith('ing') && lower.length > 5 && words[lower.slice(0,-3)]) {
                            return words[lower.slice(0,-3)];
                        }
                        if (lower.endsWith('ed') && lower.length > 4 && words[lower.slice(0,-2)]) {
                            return words[lower.slice(0,-2)];
                        }
                        if (lower.endsWith('es') && lower.length > 4 && words[lower.slice(0,-2)]) {
                            return words[lower.slice(0,-2)];
                        }
                        if (lower.endsWith('s') && lower.length > 3 && words[lower.slice(0,-1)]) {
                            return words[lower.slice(0,-1)];
                        }
                        if (\(collectUntranslated) && lower.length >= 3 && lower.length <= 20) {
                            untranslatedSet.add(lower);
                        }
                        return match;
                    });
                }

                // 短语翻译（正则匹配，已按长度降序）
                function translatePhrases(text) {
                    let result = text;
                    for (let i = 0; i < phraseKeys.length; i++) {
                        try {
                            const key = phraseKeys[i];
                            const escaped = key.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');
                            const regex = new RegExp('\\\\b' + escaped + '\\\\b', 'gi');
                            if (regex.test(result)) {
                                result = result.replace(regex, phrases[key]);
                            }
                        } catch(e) {}
                    }
                    return result;
                }

                function translateText(text) {
                    if (!text || !text.trim()) return text;
                    const processed = text.replace(/\\s+/g, ' ').trim();
                    if (translateCache[processed]) return translateCache[processed];

                    if (/^[\\d\\s\\W_]+$/.test(processed)) return text;
                    const chineseCount = (processed.match(/[\\u4e00-\\u9fa5]/g) || []).length;
                    if (chineseCount > processed.length * 0.4) return text;
                    if (processed.length > 200) return text;

                    // 1. 先正则翻译（时间、数量）
                    let result = translateByRegex(processed);
                    if (result === null) result = processed;

                    // 2. 再短语翻译
                    result = translatePhrases(result);

                    // 3. 最后单词翻译
                    result = translateWords(result);

                    translateCache[processed] = result;
                    return result;
                }

                function translateNode(node) {
                    if (!node) return;
                    if (isInBlacklist(node)) return;

                    if (node.nodeType === 3) {
                        const text = node.textContent;
                        if (text && text.trim() && /[a-zA-Z]/.test(text)) {
                            const newText = translateText(text);
                            if (newText !== text) {
                                node.textContent = newText;
                                translatedCount++;
                            }
                        }
                        return;
                    }
                    if (node.nodeType === 1) {
                        const tag = node.tagName;
                        if (skipTags[tag]) return;
                        try {
                            if (node.alt) {
                                const t = translateText(node.alt);
                                if (t !== node.alt) node.alt = t;
                            }
                            if (node.placeholder) {
                                const t = translateText(node.placeholder);
                                if (t !== node.placeholder) node.placeholder = t;
                            }
                            if (node.title) {
                                const t = translateText(node.title);
                                if (t !== node.title) node.title = t;
                            }
                            if (node.value && (tag === 'INPUT' || tag === 'BUTTON')) {
                                const t = translateText(node.value);
                                if (t !== node.value) node.value = t;
                            }
                            if (node.getAttribute && node.getAttribute('aria-label')) {
                                const aria = node.getAttribute('aria-label');
                                const t = translateText(aria);
                                if (t !== aria) node.setAttribute('aria-label', t);
                            }
                        } catch(e) {}
                    }
                }

                // 收集所有文本节点（迭代版）
                function collectTextNodes(root) {
                    const nodes = [];
                    const stack = [root];
                    let count = 0;
                    while (stack.length > 0 && count < MAX_NODES) {
                        const node = stack.pop();
                        if (!node) continue;
                        count++;
                        if (node.nodeType === 3) {
                            if (node.textContent && node.textContent.trim() && /[a-zA-Z]/.test(node.textContent)) {
                                if (!isInBlacklist(node.parentElement)) {
                                    nodes.push(node);
                                }
                            }
                        } else if (node.nodeType === 1 && !skipTags[node.tagName] && !isInBlacklist(node)) {
                            // 翻译属性
                            translateNode(node);
                            const children = node.childNodes;
                            for (let i = children.length - 1; i >= 0; i--) {
                                stack.push(children[i]);
                            }
                        }
                    }
                    return nodes;
                }

                // 分批翻译，避免阻塞
                function translateBatch(nodes, index) {
                    const end = Math.min(index + BATCH_SIZE, nodes.length);
                    for (let i = index; i < end; i++) {
                        translateNode(nodes[i]);
                    }
                    if (end < nodes.length) {
                        setTimeout(function() { translateBatch(nodes, end); }, 10);
                    }
                }

                function translateSubtree(root) {
                    if (!root || isInBlacklist(root)) return;
                    const nodes = collectTextNodes(root);
                    translateBatch(nodes, 0);
                }

                // 动态监听
                function flushPending() {
                    if (pendingNodes.length === 0) return;
                    const nodes = pendingNodes;
                    pendingNodes = [];
                    for (let i = 0; i < nodes.length; i++) {
                        try { translateSubtree(nodes[i]); } catch(e) {}
                    }
                }

                function scheduleTranslation(node, fast) {
                    if (!node) return;
                    pendingNodes.push(node);
                    if (debounceTimer) clearTimeout(debounceTimer);
                    debounceTimer = setTimeout(flushPending, fast ? 80 : 300);
                }

                function startObserver() {
                    if (observer) return;
                    try {
                        observer = new MutationObserver(function(mutations) {
                            for (let i = 0; i < mutations.length; i++) {
                                const m = mutations[i];
                                if (m.type === 'childList') {
                                    for (let j = 0; j < m.addedNodes.length; j++) {
                                        const node = m.addedNodes[j];
                                        if (node.nodeType === 1 || node.nodeType === 3) {
                                            const isFast = node.nodeType === 1 && node.className && (
                                                node.className.includes('dropdown') ||
                                                node.className.includes('menu') ||
                                                node.className.includes('popover') ||
                                                node.className.includes('modal') ||
                                                node.className.includes('SelectMenu')
                                            );
                                            scheduleTranslation(node, isFast);
                                        }
                                    }
                                } else if (m.type === 'characterData') {
                                    const node = m.target;
                                    if (node.nodeType === 3 && !isInBlacklist(node.parentElement)) {
                                        const text = node.textContent;
                                        if (text && text.trim() && /[a-zA-Z]/.test(text)) {
                                            const newText = translateText(text);
                                            if (newText !== text) {
                                                node.textContent = newText;
                                                translatedCount++;
                                            }
                                        }
                                    }
                                }
                            }
                        });
                        observer.observe(document.body, {childList: true, subtree: true, characterData: true});
                        window.__browser_translate_observer__ = observer;
                    } catch(e) {}
                }

                // 初始翻译
                translateSubtree(document.body);

                try { document.documentElement.setAttribute('data-translated', 'true'); } catch(e) {}

                // 延迟设置标记，等待分批翻译完成
                setTimeout(function() {
                    if (translatedCount > 0) {
                        window.__browser_translated__ = true;
                    }
                }, 500);

                startObserver();

                if (\(collectUntranslated)) {
                    setTimeout(function() {
                        window.__browser_untranslated__ = Array.from(untranslatedSet);
                    }, 1000);
                }

                return {success: true, translated: translatedCount, observer: true, cacheSize: Object.keys(translateCache).length};
            } catch(e) {
                return {success: false, reason: 'exception: ' + e.message};
            }
        })();
        """
        return script
    }

    // MARK: - 本地翻译
    func translateLocalOnly(webView: WKWebView, completion: @escaping (Bool, String?) -> Void) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.translateLocalOnly(webView: webView, completion: completion)
            }
            return
        }

        let script = generateTranslateScript(collectUntranslated: isCollectingUntranslated)
        guard !script.isEmpty else {
            DispatchQueue.main.async { completion(false, "脚本生成失败") }
            return
        }

        print("[TranslateManager] 开始本地翻译（高性能版）")
        executeScript(webView: webView, script: script, attempts: 2, interval: 0.8, completion: completion)
    }

    private func executeScript(webView: WKWebView, script: String, attempts: Int, interval: TimeInterval, completion: @escaping (Bool, String?) -> Void) {
        webView.evaluateJavaScript(script) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[TranslateManager] JS执行异常: \(error.localizedDescription)")
                    if attempts > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
                            self?.executeScript(webView: webView, script: script, attempts: attempts - 1, interval: interval, completion: completion)
                        }
                    } else {
                        completion(false, "JS执行异常: \(error.localizedDescription)")
                    }
                    return
                }

                guard let dict = result as? [String: Any] else {
                    completion(false, "返回格式异常")
                    return
                }

                let success = dict["success"] as? Bool ?? false
                let reason = dict["reason"] as? String
                let translated = dict["translated"] as? Int ?? 0
                let already = dict["already"] as? Bool ?? false

                if already {
                    completion(true, "页面已翻译过")
                    return
                }

                if success {
                    print("[TranslateManager] 翻译成功，\(translated)处文本")
                    completion(true, "翻译了\(translated)处文本")
                    return
                }

                if (reason == "page_loading" || reason == "no_body") && attempts > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
                        self?.executeScript(webView: webView, script: script, attempts: attempts - 1, interval: interval, completion: completion)
                    }
                    return
                }

                // v16.11.2 词典未加载（WKUserScript可能还没注入），手动注入后重试
                if reason == "dict_not_loaded" && attempts > 0 {
                    print("[TranslateManager] 词典未注入，手动注入后重试")
                    let injectScript = self.dictionaryInjectionScript()
                    if !injectScript.isEmpty {
                        webView.evaluateJavaScript(injectScript) { _, _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                                self?.executeScript(webView: webView, script: script, attempts: attempts - 1, interval: interval, completion: completion)
                            }
                        }
                    } else {
                        completion(false, "词典注入失败")
                    }
                    return
                }

                completion(false, reason ?? "翻译失败")
            }
        }
    }

    // MARK: - 混合翻译
    func translateMixed(webView: WKWebView, onlineFallback: @escaping () -> Void, completion: @escaping (Bool, String?) -> Void) {
        translateLocalOnly(webView: webView) { success, reason in
            if success {
                completion(true, reason)
            } else {
                onlineFallback()
                completion(false, "已降级在线翻译")
            }
        }
    }

    // MARK: - 获取未翻译词条
    func getUntranslatedWords(from webView: WKWebView, completion: @escaping ([String]) -> Void) {
        let script = "(function(){try{return window.__browser_untranslated__?JSON.stringify(window.__browser_untranslated__):'[]';}catch(e){return'[]';}})();"
        webView.evaluateJavaScript(script) { result, _ in
            DispatchQueue.main.async {
                if let jsonStr = result as? String,
                   let data = jsonStr.data(using: .utf8),
                   let words = try? JSONSerialization.jsonObject(with: data) as? [String] {
                    completion(words)
                } else {
                    completion([])
                }
            }
        }
    }

    // MARK: - 还原原文
    func restoreOriginal(webView: WKWebView, completion: ((Bool) -> Void)? = nil) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.restoreOriginal(webView: webView, completion: completion)
            }
            return
        }
        let script = """
        (function() {
            try {
                if (window.__browser_translate_observer__) {
                    try { window.__browser_translate_observer__.disconnect(); } catch(e) {}
                    window.__browser_translate_observer__ = null;
                }
                if (window.__browser_translated__) {
                    window.__browser_translated__ = false;
                    document.documentElement.removeAttribute('data-translated');
                    location.reload();
                    return true;
                }
                return false;
            } catch(e) { return false; }
        })();
        """
        webView.evaluateJavaScript(script) { _, error in
            DispatchQueue.main.async {
                completion?(error == nil)
            }
        }
    }

    // MARK: - 翻译缓存
    func saveTranslationCache(forURL url: String, translations: [String: String]) {
        let cacheDir = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first ?? ""
        let translateDir = (cacheDir as NSString).appendingPathComponent("CacheManager/Level4_Offline/translate_cache")
        let fileManager = FileManager.default
        try? fileManager.createDirectory(atPath: translateDir, withIntermediateDirectories: true)
        let safeName = url.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_").replacingOccurrences(of: ".", with: "_")
        let filePath = (translateDir as NSString).appendingPathComponent("\(safeName).json")
        let cacheData: [String: Any] = ["url": url, "timestamp": Date().timeIntervalSince1970, "translations": translations]
        if let data = try? JSONSerialization.data(withJSONObject: cacheData, options: .prettyPrinted) {
            try? data.write(to: URL(fileURLWithPath: filePath))
        }
    }

    func clearAllTranslationCache() {
        let cacheDir = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first ?? ""
        let translateDir = (cacheDir as NSString).appendingPathComponent("CacheManager/Level4_Offline/translate_cache")
        let fileManager = FileManager.default
        try? fileManager.removeItem(atPath: translateDir)
        try? fileManager.createDirectory(atPath: translateDir, withIntermediateDirectories: true)
    }

    func translationCacheSize() -> Int64 {
        let cacheDir = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first ?? ""
        let translateDir = (cacheDir as NSString).appendingPathComponent("CacheManager/Level4_Offline/translate_cache")
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: translateDir) else { return 0 }
        var size: Int64 = 0
        while let file = enumerator.nextObject() as? String {
            let fullPath = (translateDir as NSString).appendingPathComponent(file)
            if let attrs = try? fileManager.attributesOfItem(atPath: fullPath) {
                size += attrs[.size] as? Int64 ?? 0
            }
        }
        return size
    }
}
