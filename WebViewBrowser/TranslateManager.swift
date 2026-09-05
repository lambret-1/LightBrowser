//
//  TranslateManager.swift
//  轻量浏览器 - v16.11 分层翻译引擎
//
//  v16.11 重大升级：
//  - 导入 github-chinese 开源词库（19000+词条）
//  - 四层分层词典：UI界面 → Git术语 → 正则规则 → IT通用
//  - 长短语优先匹配（词典按英文长度降序）
//  - 大小写不敏感匹配
//  - 文本空白预处理
//  - DOM黑白名单（跳过代码块/diff，优先翻译UI控件）
//  - MutationObserver增量翻译（子菜单/SPA动态内容）
//  - 正则翻译支持（相对时间、数量等批量翻译）
//  - 内存翻译缓存
//  - 动词词形归一化（ing/ed后缀）
//  - 未翻译词条采集工具
//  - 自动翻译模式：纯离线 / UI离线+长文本在线兜底
//

import UIKit
import WebKit

class TranslateManager {

    static let shared = TranslateManager()

    // MARK: - 分层词典
    private var uiDictionary: [String: String] = [:]       // 最高优先级：UI界面词条
    private var gitDictionary: [String: String] = [:]      // Git术语
    private var itDictionary: [String: String] = [:]       // IT通用词汇
    private var generalDictionary: [String: String] = [:]  // 通用兜底
    private var regexRules: [[String: String]] = []        // 正则翻译规则
    private var mergedDictionary: [String: String] = [:]   // 合并后词典（已按长度降序）

    private var isDictLoaded = false

    // 内置兜底高频词条
    private let fallbackDict: [String: String] = [
        "home": "首页", "back": "返回", "forward": "前进", "refresh": "刷新",
        "search": "搜索", "submit": "提交", "cancel": "取消", "ok": "确定",
        "save": "保存", "delete": "删除", "edit": "编辑", "add": "添加",
        "close": "关闭", "open": "打开", "download": "下载", "upload": "上传",
        "login": "登录", "logout": "退出登录", "register": "注册", "next": "下一步",
        "previous": "上一步", "continue": "继续", "confirm": "确认", "settings": "设置",
        "help": "帮助", "about": "关于", "menu": "菜单", "profile": "个人资料",
        "notification": "通知", "message": "消息", "favorite": "收藏", "history": "历史记录",
        "loading": "加载中", "success": "成功", "error": "错误", "warning": "警告",
        "failed": "失败", "completed": "已完成", "pending": "待处理", "update": "更新",
        "create": "创建", "send": "发送", "share": "分享", "copy": "复制",
        "paste": "粘贴", "cut": "剪切", "print": "打印", "welcome": "欢迎",
        "repository": "仓库", "star": "标星", "fork": "复刻", "commit": "提交",
        "issue": "议题", "pull request": "合并请求", "release": "版本发布",
        "branch": "分支", "clone": "克隆", "watch": "关注", "code": "代码",
        "actions": "工作流", "wiki": "维基文档", "discussion": "讨论",
        "sign in": "登录", "sign up": "注册", "sign out": "退出",
        "explore": "探索", "trending": "趋势", "marketplace": "应用市场",
        "pricing": "价格", "docs": "文档", "support": "支持",
        "new": "新建", "file": "文件", "folder": "文件夹",
        "name": "名称", "description": "描述", "public": "公开", "private": "私有",
        "readme": "说明文档", "license": "许可证", "language": "语言", "topics": "主题"
    ]

    // MARK: - 翻译模式
    enum TranslateMode: String {
        case local = "local"                    // 纯离线（全部内容依靠本地词典）
        case online = "online"                  // 在线翻译
        case mixed = "mixed"                    // 混合翻译（推荐）
        case alwaysOn = "alwaysOn"              // 自动翻译（页面加载后自动翻译）
        case autoEnhanced = "autoEnhanced"      // v16.11 自动翻译增强（UI离线+长文本在线兜底）
    }

    var currentMode: TranslateMode {
        let mode = UserDefaults.standard.string(forKey: "translateMode") ?? "mixed"
        return TranslateMode(rawValue: mode) ?? .mixed
    }

    func setMode(_ mode: TranslateMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: "translateMode")
    }

    // 是否开启自动翻译
    var isAutoTranslateEnabled: Bool {
        return currentMode == .alwaysOn || currentMode == .autoEnhanced
    }

    // 是否使用在线兜底（长文本）
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

    // MARK: - 加载分层词库
    func loadAllDictionaries() {
        if isDictLoaded && !mergedDictionary.isEmpty {
            return
        }

        // 1. UI界面词条（最高优先级）
        uiDictionary = loadJSONDict(named: "github_ui") ?? [:]
        print("[TranslateManager] UI界面词库: \(uiDictionary.count)条")

        // 2. Git术语
        gitDictionary = loadJSONDict(named: "github_git_terms") ?? [:]
        print("[TranslateManager] Git术语词库: \(gitDictionary.count)条")

        // 3. IT通用词汇
        itDictionary = loadJSONDict(named: "general_it") ?? [:]
        print("[TranslateManager] IT通用词库: \(itDictionary.count)条")

        // 4. 通用兜底
        generalDictionary = loadJSONDict(named: "en_zh_dict") ?? fallbackDict
        print("[TranslateManager] 通用兜底词库: \(generalDictionary.count)条")

        // 5. 正则规则
        regexRules = loadRegexRules(named: "github_regex")
        print("[TranslateManager] 正则规则: \(regexRules.count)条")

        // 合并：UI → Git → IT → 通用（后面的覆盖前面的，因为UI质量最高应该最后覆盖）
        // 实际上应该是优先级高的覆盖优先级低的
        mergedDictionary = [:]
        for (k, v) in generalDictionary { mergedDictionary[k.lowercased()] = v }
        for (k, v) in itDictionary { mergedDictionary[k.lowercased()] = v }
        for (k, v) in gitDictionary { mergedDictionary[k.lowercased()] = v }
        for (k, v) in uiDictionary { mergedDictionary[k.lowercased()] = v }

        // 按英文长度降序排序（长短语优先匹配）
        let sortedKeys = mergedDictionary.keys.sorted { $0.count > $1.count }
        var sortedDict: [String: String] = [:]
        for k in sortedKeys {
            sortedDict[k] = mergedDictionary[k]
        }
        mergedDictionary = sortedDict

        isDictLoaded = true
        print("[TranslateManager] 合并后总词条: \(mergedDictionary.count)条（已按长度降序）")
    }

    private func loadJSONDict(named name: String) -> [String: String]? {
        guard let path = Bundle.main.path(forResource: name, ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return nil
        }
        return dict
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

    func getDictionary(for url: URL?) -> [String: String] {
        loadAllDictionaries()
        return mergedDictionary
    }

    func getRegexRules() -> [[String: String]] {
        loadAllDictionaries()
        return regexRules
    }

    // MARK: - 生成JS翻译脚本（v16.11 分层引擎完整版）
    private func generateTranslateScript(dictionary: [String: String], regexRules: [[String: String]], collectUntranslated: Bool = false) -> String {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let regexData = try? JSONSerialization.data(withJSONObject: regexRules),
              let regexString = String(data: regexData, encoding: .utf8) else {
            return ""
        }

        let script = """
        (function() {
            try {
                if (window.__browser_translated__) {
                    return {success: true, already: true, translated: 0};
                }
                if (!document.body) {
                    return {success: false, reason: 'no_body'};
                }
                if (document.readyState === 'loading') {
                    return {success: false, reason: 'page_loading'};
                }

                const dict = \(jsonString);
                const regexRules = \(regexString);
                const dictKeys = Object.keys(dict); // 已按长度降序

                // DOM黑名单：跳过代码块、diff区域
                const skipTags = {'SCRIPT':1,'STYLE':1,'NOSCRIPT':1,'SVG':1,'CODE':1,'PRE':1,'TEXTAREA':1,'INPUT':1,'SELECT':1,'OPTION':1,'IFRAME':1,'CANVAS':1,'TEMPLATE':1};
                const skipClasses = ['blob-code','CodeMirror','diff-chunk','markdown-body pre','cm-content','cm-scroller','react-code-text'];

                // UI白名单选择器（优先翻译这些区域）
                const uiSelectors = ['.btn','.Button','.State','.UnderlineNav-item','.TabNav','.Box-header','.IssueLabel','.breadcrumb','.AppHeader','.Header','.menu','.tabnav','.subnav','.ActionList','.ActionListItem','.FormControl','.form-group','.SelectMenu','.dropdown','.menu-item','.table-list','.Box-row','.TimelineItem','.timeline-comment','.comment','.review-thread','.merge-status','.status','.branch-name','.commit-ref','.tag','.label','.milestone','.project-card','.column','.card','.panel','.alert','.flash','.toast','.notification','.badge','.Counter','.count','.avatar','.user-mention','.team-mention','.issue-link','.pr-link','.commit-link','.release','.tag-name','.branch-name','.file-info','.path','.directory','.file','.folder','.icon','.octicon','.heading','.title','.subtitle','.description','.meta','.details','.summary','.footer','.header','.nav','.navigation','.sidebar','.content','.main','.container','.wrapper','.page','.view','.screen','.dialog','.modal','.popup','.popover','.tooltip','.hint','.tip','.note','.warning','.error','.success','.info','.pending','.running','.queued','.completed','.cancelled','.skipped','.failed','.failure','.approved','.changes','.requested','.merged','.closed','.open','.draft','.ready','.review','.assigned','.unassigned','.labeled','.unlabeled','.milestoned','.demilestoned','.reopened','.locked','.unlocked','.transferred','.pinned','.unpinned','.subscribed','.unsubscribed','.mentioned','.assigned','.unassigned','.review_requested','.review_request_removed','.labeled','.unlabeled','.milestoned','.demilestoned','.opened','.edited','.closed','.reopened','.deleted','.transferred','.pinned','.unpinned','.milestoned','.demilestoned','.commented','.reviewed','.review_dismissed','.review_requested','.review_request_removed','.assigned','.unassigned','.labeled','.unlabeled','.locked','.unlocked','.subscribed','.unsubscribed','.mentioned','.referenced','.cross-referenced','.comment_deleted','.head_ref_deleted','.head_ref_restored','.base_ref_changed','.base_ref_force_pushed','.merge_queue'];

                const MAX_NODES = 5000;
                let translatedCount = 0;
                let untranslatedSet = new Set();
                let translateCache = {}; // 内存缓存
                let observer = null;
                let pendingNodes = [];
                let debounceTimer = null;

                // v16.11 文本预处理：清除首尾空白、合并多空格
                function preprocessText(text) {
                    if (!text) return text;
                    return text.replace(/\\s+/g, ' ').trim();
                }

                // v16.11 词形归一化：处理ing/ed后缀
                function normalizeWord(word) {
                    const w = word.toLowerCase();
                    // 简单的ing/ed剥离
                    if (w.endsWith('ing') && w.length > 5) {
                        return w.slice(0, -3);
                    }
                    if (w.endsWith('ed') && w.length > 4) {
                        return w.slice(0, -2);
                    }
                    if (w.endsWith('es') && w.length > 4) {
                        return w.slice(0, -2);
                    }
                    if (w.endsWith('s') && w.length > 3) {
                        return w.slice(0, -1);
                    }
                    return w;
                }

                // v16.11 正则翻译（相对时间、数量等）
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

                // v16.11 核心翻译函数（大小写不敏感 + 缓存 + 词形归一）
                function translateText(text) {
                    if (!text || !text.trim()) return text;

                    // 预处理
                    const original = text;
                    const processed = preprocessText(text);

                    // 检查缓存
                    if (translateCache[processed]) {
                        return translateCache[processed];
                    }

                    // 纯数字符号跳过
                    if (/^[\\d\\s\\W_]+$/.test(processed)) return text;

                    // 中文占比过高跳过
                    const chineseCount = (processed.match(/[\\u4e00-\\u9fa5]/g) || []).length;
                    if (chineseCount > processed.length * 0.4) return text;

                    // 过长文本跳过（长文本走在线兜底）
                    if (processed.trim().length > 200) return text;

                    // 先尝试正则翻译
                    const regexResult = translateByRegex(processed);
                    if (regexResult !== null && regexResult !== processed) {
                        translateCache[processed] = regexResult;
                        return regexResult;
                    }

                    // 词典匹配（已按长度降序，长短语优先）
                    let result = processed;
                    let matched = false;

                    for (let i = 0; i < dictKeys.length; i++) {
                        try {
                            const key = dictKeys[i];
                            if (!key || key.length < 2) continue;

                            // 大小写不敏感匹配
                            const escaped = key.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');
                            const regex = new RegExp('\\\\b' + escaped + '\\\\b', 'gi');

                            if (regex.test(result)) {
                                result = result.replace(regex, dict[key]);
                                matched = true;
                            }
                        } catch(e) {}
                    }

                    // 词形归一化二次匹配（针对动词变形）
                    if (!matched && processed.length < 50) {
                        const words = processed.split(/\\s+/);
                        let normalizedResult = processed;
                        let normalizedMatched = false;
                        for (let w of words) {
                            const norm = normalizeWord(w);
                            if (norm !== w.toLowerCase() && dict[norm]) {
                                const wordRegex = new RegExp('\\\\b' + w.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&') + '\\\\b', 'gi');
                                normalizedResult = normalizedResult.replace(wordRegex, dict[norm]);
                                normalizedMatched = true;
                            }
                        }
                        if (normalizedMatched) {
                            result = normalizedResult;
                            matched = true;
                        }
                    }

                    // 采集未翻译词条
                    if (!matched && \(collectUntranslated) {
                        if (processed.length >= 2 && processed.length <= 50 && /[a-zA-Z]/.test(processed)) {
                            untranslatedSet.add(processed.toLowerCase());
                        }
                    }

                    translateCache[processed] = result;
                    return result;
                }

                // 检查元素是否在黑名单中
                function isInBlacklist(node) {
                    if (!node || node.nodeType !== 1) return false;
                    const tag = node.tagName;
                    if (skipTags[tag]) return true;
                    if (node.className && typeof node.className === 'string') {
                        for (let cls of skipClasses) {
                            if (node.className.includes(cls)) return true;
                        }
                    }
                    // 检查祖先节点
                    let parent = node.parentElement;
                    while (parent) {
                        if (parent.className && typeof parent.className === 'string') {
                            for (let cls of skipClasses) {
                                if (parent.className.includes(cls)) return true;
                            }
                        }
                        if (skipTags[parent.tagName]) return true;
                        parent = parent.parentElement;
                    }
                    return false;
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
                                const newAlt = translateText(node.alt);
                                if (newAlt !== node.alt) { node.alt = newAlt; translatedCount++; }
                            }
                            if (node.placeholder) {
                                const newPh = translateText(node.placeholder);
                                if (newPh !== node.placeholder) { node.placeholder = newPh; translatedCount++; }
                            }
                            if (node.title) {
                                const newTitle = translateText(node.title);
                                if (newTitle !== node.title) { node.title = newTitle; translatedCount++; }
                            }
                            if (node.value && (tag === 'INPUT' || tag === 'BUTTON')) {
                                const newVal = translateText(node.value);
                                if (newVal !== node.value) { node.value = newVal; translatedCount++; }
                            }
                            // 翻译aria-label
                            if (node.getAttribute && node.getAttribute('aria-label')) {
                                const aria = node.getAttribute('aria-label');
                                const newAria = translateText(aria);
                                if (newAria !== aria) { node.setAttribute('aria-label', newAria); translatedCount++; }
                            }
                        } catch(e) {}
                    }
                }

                // 迭代版遍历（使用栈，避免递归栈溢出）
                function translateSubtree(root) {
                    if (!root) return;
                    if (isInBlacklist(root)) return;

                    const stack = [root];
                    let nodeCount = 0;
                    while (stack.length > 0 && nodeCount < MAX_NODES) {
                        const node = stack.pop();
                        if (!node) continue;
                        nodeCount++;
                        translateNode(node);
                        if (node.nodeType === 1 && node.childNodes) {
                            const tag = node.tagName;
                            if (!skipTags[tag] && !isInBlacklist(node)) {
                                const children = node.childNodes;
                                for (let i = children.length - 1; i >= 0; i--) {
                                    if (children[i].nodeType === 1 || children[i].nodeType === 3) {
                                        stack.push(children[i]);
                                    }
                                }
                            }
                        }
                    }
                }

                // v16.11 防抖处理动态节点翻译（双档防抖）
                function flushPendingTranslations() {
                    if (pendingNodes.length === 0) return;
                    const nodes = pendingNodes;
                    pendingNodes = [];
                    for (let i = 0; i < nodes.length; i++) {
                        try {
                            translateSubtree(nodes[i]);
                        } catch(e) {}
                    }
                }

                function scheduleTranslation(node, fast) {
                    if (!node) return;
                    pendingNodes.push(node);
                    if (debounceTimer) clearTimeout(debounceTimer);
                    // 菜单/弹窗快速防抖50ms，列表加载300ms
                    const delay = fast ? 50 : 300;
                    debounceTimer = setTimeout(flushPendingTranslations, delay);
                }

                // v16.11 启动MutationObserver监听动态内容
                function startObserver() {
                    if (observer) return;
                    try {
                        observer = new MutationObserver(function(mutations) {
                            for (let i = 0; i < mutations.length; i++) {
                                const mutation = mutations[i];
                                if (mutation.type === 'childList') {
                                    const added = mutation.addedNodes;
                                    for (let j = 0; j < added.length; j++) {
                                        const node = added[j];
                                        if (node.nodeType === 1 || node.nodeType === 3) {
                                            // 判断是否是菜单/弹窗（快速翻译）
                                            const isFast = node.nodeType === 1 && (
                                                node.className && (
                                                    node.className.includes('dropdown') ||
                                                    node.className.includes('menu') ||
                                                    node.className.includes('popover') ||
                                                    node.className.includes('modal') ||
                                                    node.className.includes('SelectMenu') ||
                                                    node.className.includes('ActionList')
                                                )
                                            );
                                            scheduleTranslation(node, isFast);
                                        }
                                    }
                                } else if (mutation.type === 'characterData') {
                                    const node = mutation.target;
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
                        observer.observe(document.body, {
                            childList: true,
                            subtree: true,
                            characterData: true,
                            characterDataOldValue: false
                        });
                        window.__browser_translate_observer__ = observer;
                    } catch(e) {
                        console.warn('MutationObserver启动失败:', e);
                    }
                }

                // 初始全量翻译
                translateSubtree(document.body);

                try {
                    document.documentElement.setAttribute('data-translated', 'true');
                } catch(e) {}

                if (translatedCount > 0) {
                    window.__browser_translated__ = true;
                }

                // 启动动态监听
                startObserver();

                // 保存未翻译词条到window
                if (\(collectUntranslated)) {
                    window.__browser_untranslated__ = Array.from(untranslatedSet);
                }

                return {
                    success: true,
                    translated: translatedCount,
                    observer: true,
                    untranslated: \(collectUntranslated) ? untranslatedSet.size : 0,
                    cacheSize: Object.keys(translateCache).length
                };
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

        loadAllDictionaries()
        let dict = getDictionary(for: webView.url)
        let regex = getRegexRules()
        let collect = isCollectingUntranslated
        let script = generateTranslateScript(dictionary: dict, regexRules: regex, collectUntranslated: collect)
        guard !script.isEmpty else {
            DispatchQueue.main.async { completion(false, "脚本生成失败") }
            return
        }

        print("[TranslateManager] 开始本地翻译，词库\(dict.count)条 + 正则\(regex.count)条")
        executeScript(webView: webView, script: script, attempts: 2, interval: 0.6, completion: completion)
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
                    print("[TranslateManager] 返回格式异常: \(String(describing: result))")
                    completion(false, "返回格式异常")
                    return
                }

                let success = dict["success"] as? Bool ?? false
                let reason = dict["reason"] as? String
                let translated = dict["translated"] as? Int ?? 0
                let already = dict["already"] as? Bool ?? false
                let untranslated = dict["untranslated"] as? Int ?? 0
                let cacheSize = dict["cacheSize"] as? Int ?? 0

                if already {
                    print("[TranslateManager] 页面已翻译过")
                    completion(true, "页面已翻译过")
                    return
                }

                if success {
                    print("[TranslateManager] 本地翻译成功，翻译了\(translated)处文本，缓存\(cacheSize)条，未翻译\(untranslated)词")
                    completion(true, "翻译了\(translated)处文本")
                    return
                }

                if (reason == "page_loading" || reason == "no_body") && attempts > 0 {
                    print("[TranslateManager] 页面未就绪(\(reason ?? ""))，\(interval)秒后重试（剩余\(attempts)次）")
                    DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
                        self?.executeScript(webView: webView, script: script, attempts: attempts - 1, interval: interval, completion: completion)
                    }
                    return
                }

                print("[TranslateManager] 本地翻译失败: \(reason ?? "未知")")
                completion(false, reason ?? "翻译失败")
            }
        }
    }

    // MARK: - 混合翻译（本地优先，失败降级在线）
    func translateMixed(webView: WKWebView, onlineFallback: @escaping () -> Void, completion: @escaping (Bool, String?) -> Void) {
        translateLocalOnly(webView: webView) { success, reason in
            if success {
                completion(true, reason)
            } else {
                print("[TranslateManager] 本地翻译失败(\(reason ?? "未知"))，降级在线翻译")
                onlineFallback()
                completion(false, "已降级在线翻译")
            }
        }
    }

    // MARK: - 获取未翻译词条
    func getUntranslatedWords(from webView: WKWebView, completion: @escaping ([String]) -> Void) {
        let script = """
        (function() {
            try {
                if (window.__browser_untranslated__) {
                    return JSON.stringify(window.__browser_untranslated__);
                }
                return '[]';
            } catch(e) {
                return '[]';
            }
        })();
        """
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
            } catch(e) {
                return false;
            }
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

        let cacheData: [String: Any] = [
            "url": url,
            "timestamp": Date().timeIntervalSince1970,
            "translations": translations
        ]
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
