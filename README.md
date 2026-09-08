# 轻量浏览器 - iOS 轻量浏览器

一个基于 WKWebView 的 iOS 浏览器，支持手势导航、多窗口、广告拦截、VLESS 代理、节点测速等功能。

## 当前版本：v16.17.22

## v16.17.22 更新日志
- App进入前台禁止网页自动刷新
  - 移除所有前台恢复时的自动刷新逻辑
  - WebKit进程被系统终止时不再自动刷新，仅记录调试日志
  - 无任何弹窗提示，静默处理
  - 自动版本检测功能保持正常（与网页刷新隔离）
  - 页面白屏时由用户手动下拉刷新恢复

## v16.17.21 更新日志
- 修复更新下载跳转外部浏览器的问题
  - 点击「下载更新」/「立即更新」后，在当前浏览器内下载 IPA
  - 不再跳转到 Safari，使用内置下载管理器
  - 下载完成后可在下载管理中找到 IPA，用 TrollStore 安装

## v16.17.20 更新日志
- 测试版本：验证自动检测更新功能
- 安装 v16.17.19 后检查更新应能检测到此版本

## v16.17.19 更新日志
- 修复 DNS 配置描述文件（.mobileconfig）无法安装的问题
  - 检测到 .mobileconfig 链接时自动唤起 Safari 打开
  - iOS 系统限制：描述文件必须通过 Safari 才能安装
- 版本检测增加调试日志
  - 记录本地版本、远程版本、是否有更新、IPA附件数量
  - 请求失败、解析失败均记录错误日志
- Release IPA 文件名规范统一：LightBrowser-v{版本号}.ipa

## v16.17.18 更新日志
- 新增自动检测更新功能
  - 设置 → 关于 → 「启动时自动检测更新」开关（默认开启）
  - App 进入前台时自动后台检测 GitHub Release 新版本
  - 距上次检查超过1小时才重新检测，避免频繁请求
  - 发现新版本弹窗提示，支持「立即更新」直接下载 IPA
  - 无新版本静默不提示

## v16.17.17 更新日志
- 检查更新功能增强：发现新版本时支持直接下载 IPA
- 创建首个 GitHub Release（v16.17.16），IPA 已上传
- 以后每次版本更新自动创建 Release 并上传 IPA

## v16.17.16 更新日志
- 设置中心完整重构
  - 5大分组：通用 / 隐私与拦截 / 性能 / 高级 / 关于
  - 顶部搜索框：输入关键词实时过滤设置项
  - 通用：地址栏位置、默认搜索引擎、UA切换、手势灵敏度、菜单弹出速度
  - 隐私与拦截：广告拦截开关、全局图片拦截、广告黑名单管理、缓存管理
  - 性能：DNS预解析、禁止媒体自动播放、后台动画节流、内存告警自动清理、性能日志
  - 高级：调试日志、代理配置、配置导出/导入(JSON)、重置全部设置
  - 关于：当前版本、检查更新（对比GitHub Release）、GitHub仓库跳转
- 新增 SettingsManager 统一设置管理器，支持导入导出、重置
- 所有设置页面统一导航栏样式，左侧返回/关闭按钮
- 旧的分散设置弹窗全部移除，统一收敛到新设置中心

## v16.17.15 更新日志
- 新增性能优化管理器 PerformanceOptimizer
  - 启动时间监控：记录应用启动耗时并写入调试日志
  - WebView 配置优化：多标签共享进程池、媒体不自动播放、内联播放
  - DNS 预解析：启动后异步预解析 GitHub/CF/Google/YouTube 域名
  - 内存警告处理：收到内存警告时自动清理旧缓存
  - 后台标签优化：切换标签时暂停后台标签的媒体播放
  - 网页加载监控：记录每个网页的加载耗时
  - 前后台切换优化：进入后台/前台时记录日志

## v16.17.14 更新日志
- 修复调试日志页面无返回按钮：添加导航栏"完成"关闭按钮
- 增加日志记录点：网页加载完成/失败、标签切换、查找执行/失败、清除高亮失败
- 优化网页查找功能：TreeWalker 改为递归遍历文本节点，兼容性更好，支持代码块内查找
- 查找功能添加调试日志：记录匹配数、遍历节点数、执行失败原因

## v16.17.13 更新日志
- 新增全局调试日志功能
  - 崩溃自动捕获：NSException + Unix信号（SIGABRT/SIGILL/SIGSEGV/SIGFPE/SIGBUS/SIGPIPE）
  - 崩溃日志包含时间、异常名、原因、完整调用栈
  - 手动日志：logInfo/logWarning/logError 三级日志
  - 日志查看页面：功能菜单 → 调试日志
  - 支持复制、分享、清空、刷新操作
  - 日志文件存储在 Documents/debug_log.txt，最大2MB自动截断
  - 应用启动时自动记录启动日志

## v16.17.12 更新日志
- 优化查找跳转速度：findNext/findPrev 与高亮滚动合并为单次JS调用，减少 evaluateJavaScript 延迟
- 修复查找菜单项不置顶：iOS16+ 使用 WKUIDelegate editMenuConfigurationForElement 完全控制菜单，「🔍 查找」强制第一个，禁用系统默认菜单（copy/paste/cut/lookup/translate/share）
- iOS14-15 继续使用 UIMenuController + canPerformAction 方案

## v16.17.11 更新日志
- 修复查找功能滚动反应迟钝：平滑滚动改为瞬间滚动（behavior:'auto'），点击上一个/下一个立即跳转
- 修复查找菜单项不置顶：canPerformAction 改为只允许自定义菜单项，屏蔽所有系统默认菜单（定义/翻译/分享/朗读等），确保「🔍 查找」显示在第一个

## v16.17.10 更新日志
- 修复网页查找功能：放弃系统原生 findInteraction，所有版本统一使用自定义查找栏 + JS 高亮
- 重写 JS 搜索引擎：TreeWalker 遍历所有文本节点（含代码块），安全转义关键词，防无限循环
- 修复关闭查找栏后黄色高亮不清除的问题：简化清除逻辑，添加错误日志
- 修复上一个/下一个滚动不跟踪问题：改用 getBoundingClientRect + window.scrollTo 强制滚动居中
- 查找菜单项置顶：长按选中文字时，「🔍 查找」显示在菜单第一个
- 自定义查找栏支持键盘跟随：键盘弹出时自动上移到键盘顶部

## v16.17.9 更新日志
- 新增网页文字查找功能
  - 长按选中文字时，系统菜单新增「🔍 查找」选项
  - iOS16+ 使用系统原生 findInteraction 查找导航器（稳定高效，自动支持代码块）
  - iOS14-15 使用自定义底部查找栏 + JS TreeWalker 高亮兜底
  - 支持代码块 `<pre><code>` 内文本高亮匹配
  - 上一个/下一个按钮跳转，当前匹配项橙色高亮并滚动居中
  - 匹配计数显示 "当前/总数"
  - 切换标签页自动关闭查找栏并清除高亮

## v16.17.8 更新日志
- 新增 Safari 式网页快照恢复功能（方案A）
  - APP 切后台时自动保存每个标签的 URL、滚动位置、页面截图
  - APP 重启时先显示上次网页截图，后台悄悄加载网页
  - 网页加载完成后自动恢复滚动位置，截图淡出消失
  - 视觉效果与 Safari 一致，用户感知不到重新加载
- 新增设置开关：「📸 页面快照恢复」，默认关闭，可手动开启
- 关闭快照恢复时自动清除所有已保存的快照文件

## v16.17.7 更新日志
- 翻译按钮单击功能改为「自动翻译增强模式」开关
  - 单击开启自动翻译增强（按钮变绿色），立即执行一次翻译
  - 再次单击关闭（按钮恢复浅蓝色），切换为混合翻译模式
- 移除所有翻译过程提示（正在翻译、翻译完成、翻译失败等 Toast）
- 翻译按钮状态根据自动翻译增强模式显示：开启=绿色，关闭=浅蓝色

## v16.17.6 更新日志
- GitHub 翻译词库大幅扩充：从 maboloshi/github-chinese 和 Emilcookie/github-chinese 两个开源项目下载最新 locals.js 词库
- 解析合并去重后，github_ui.json 从 13,153 条扩充至 26,068 条（新增 12,915 条）
- 清理 136 条未翻译的无效条目
- 词库覆盖 GitHub 全站界面元素：菜单栏、按钮、设置页、仓库页、Issue、PR、Actions、Codespaces 等

## v16.17.5 更新日志
- 彻底删除全部 AI 对话相关代码（AIChatViewController、AIModelManager、MarkdownRenderer、ConversationManager、KnowledgeBaseManager、VoiceService、WebAIIntegration），解决 AI 模块导致的应用闪退
- 功能菜单触发方式迁移：从右边缘下滑改为**长按 GitHub 标签按钮**呼出
- 翻译按钮长按响应时间从 0.4 秒缩短至 0.2 秒，提升交互响应速度
- 第4个标签恢复为 YouTube
- 标签长按功能恢复：GitHub→功能菜单、CF→清除缓存、Google→管理窗口、YouTube→书签列表

## v15.7 更新日志
- 应用名称更改为「轻量浏览器」
- 打包方式回退为未签名 IPA（适配 TrollStore 安装）
- 修复下载功能：添加缺失的 `webView(_:navigationResponse:didBecome:)` 方法，iOS 15+ 原生下载现在可以正常工作
- 修复工具栏位置切换：在 viewDidLoad 中调用 applyToolbarPosition()，设置后重启生效
- 默认浏览器功能改为说明提示（TrollStore 免签名版本受系统限制无法设置默认浏览器）
- Info.plist 注册 HTTP/HTTPS URL Scheme，为以后正规签名支持默认浏览器做准备

## 功能特性

### 核心浏览功能
- 多窗口浏览（4个标签页，可自定义名称和地址）
- 右滑后退、左滑前进（跟随手指拖拽）
- 下拉刷新（70pt 触发高度）
- 双击右下角回顶部、双击左下角回底部
- 双击翻译键刷新当前网页
- 地址栏智能搜索（支持 Google/百度/Bing/DuckDuckGo）
- 地址栏双击复制当前 URL
- 地址栏位置可切换（顶部/底部，重启生效）

### 翻译功能
- 一键翻译当前网页（英文→中文）
- 翻译键长按弹出设置菜单
- 翻译键可自定义位置和大小

### 下载管理
- 原生 WKDownload 下载（iOS 15+）
- iOS 14 自动降级 URLSession 下载
- 下载进度条和角标提示
- 下载文件保存到 Documents/Downloads
- 支持在"文件"App 中查看下载内容

### 广告拦截
- 基于 WKContentRuleList 的域名拦截
- 全局图片广告拦截开关
- 自定义广告黑名单（支持添加/删除/编辑）
- 一键拦截当前网站所有图片
- 扩充版广告拦截黑名单

### 缓存管理
- 四级缓存系统（内存/瞬时/持久/磁盘）
- 24小时自动清空过期缓存
- 缓存管理页面显示手机存储状态和浏览器缓存大小
- 支持清空当前站点缓存和一键清空全部缓存

### VLESS 代理
- AppProxyExtension 网络扩展
- 支持直连模式和 VLESS-WS 模式
- VLESS 节点管理（添加/删除/切换）
- 节点延迟测速（批量测试，按延迟排序）
- 订阅管理器（支持 HTTP/HTTPS 订阅，Base64 解码）
- 支持解析 vless/vmess/trojan 节点

### 右边缘功能菜单
- 从屏幕右边缘滑出（50% 宽度）
- 弹出动画 1 秒
- 功能项可拖拽排序
- 包含：增加书签、书签列表、历史记录、下载管理、全局图片拦截、UA 切换、广告黑名单、缓存管理、高级代理、设置

### 设置功能
- 搜索引擎切换（Google/百度/Bing/DuckDuckGo）
- 地址栏位置切换（顶部/底部）
- 默认浏览器设置指引
- 版本号显示
- 权限管理（一键开启全部权限）

### 其他功能
- UA 切换（iPhone/iPad/Mac/Windows Chrome/Windows Edge）
- 网页内文字搜索（高亮匹配，上下跳转）
- 书签管理（长按标签添加/打开/管理）
- Safari 风格历史记录
- 四级缓存优化
- DNS 预解析和 TCP 预连接
- 禁止媒体自动播放
- 网页强制缩放

## 系统要求
- 最低 iOS 14.0
- 推荐 iOS 15.0+（支持原生 WKDownload）
- TrollStore 安装（推荐，永久签名）

## 安装方式
### TrollStore（推荐）
1. 彻底卸载旧版本
2. 用 TrollStore 打开 IPA 全新安装
3. 首次开启 VPN 代理需允许添加 VPN 配置

### 爱思助手
1. 连接手机到电脑
2. 用爱思助手导入 IPA 安装
3. 注意：AdHoc 证书需绑定设备 UDID

## 项目结构
```
WebViewBrowser/
├── ViewController.swift      # 主界面（浏览器核心逻辑）
├── DownloadManager.swift     # 下载管理器
├── VLESSClient.swift         # VLESS 客户端和节点管理
├── DownloadPanelViewController.swift  # 下载管理面板
├── Info.plist                # 应用配置
├── WebViewBrowser.entitlements  # 主App权限
└── Assets.xcassets/
AppProxyExtension/
├── AppProxyProvider.swift    # 代理核心（直连+VLESS）
├── VLESSClient.swift         # Extension用VLESS客户端
├── AppProxyExtension.entitlements  # Extension权限
└── Info.plist
.github/workflows/
└── build.yml                 # GitHub Actions 构建流程
```

## 构建
通过 GitHub Actions 自动构建：
1. 推送代码到 main 分支
2. 自动触发构建
3. 构建完成后在 Actions 页面下载 IPA
4. 使用用户证书签名（配置 GitHub Secrets）

## 版本历史
- v15.5: 修复下载功能语法错误、工具栏位置切换、缓存管理改造、全面汉化
- v15.4: 修复工具栏位置切换、默认浏览器指引、全汉化、VPN终极ldid签名
- v15.3: 设置移至侧边菜单、菜单速度1s、手势交换右滑后退左滑前进
- v15.2: 修复permission denied、下载bug、新增设置功能
- v15.1: 修复Extension签名问题，支持TrollStore
- v15.0: 新增节点延迟测试功能
- v14.9: iOS 14 降级兼容
