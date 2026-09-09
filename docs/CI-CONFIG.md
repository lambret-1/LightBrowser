# 轻量浏览器 - CI/CD 仓库环境配置手册

## 仓库目录结构

```
LightBrowser/
├── .github/
│   └── workflows/
│       ├── build.yml          # 生产构建流水线（main分支触发）
│       └── pr-check.yml       # PR质量门禁（PR/非main分支触发）
├── scripts/
│   ├── version-bump.sh        # 三段语义版本递增脚本
│   ├── version-bump-test.sh   # 版本递增单元测试（25个用例）
│   ├── update-readme.sh       # README更新日志自动插入
│   └── generate-metadata.sh   # 制品元数据JSON生成
├── WebViewBrowser/            # iOS 源码（纯Swift + WKWebView）
├── AppProxyExtension/         # Network Extension 代理扩展
├── WebViewBrowser.xcodeproj/  # Xcode 项目文件
└── README.md                  # 项目说明 + 更新日志
```

## GITHUB_TOKEN 权限说明

生产流水线 `build.yml` 需要以下权限：
- `contents: write` — 用于：
  - 提交版本递增变更（Info.plist）
  - 提交 README 更新日志
  - 创建 Git Tag
  - 创建 Draft Release
  - 上传 Release 附件

**无需配置任何 Secrets**，使用 GitHub 自动注入的 `GITHUB_TOKEN` 即可。

## 触发规则

| 事件 | 流水线 | 行为 |
|------|--------|------|
| push 到 main | build.yml | 完整生产流水线：版本递增→编译→Draft Release |
| 手动触发 | build.yml | 同上 |
| Pull Request | pr-check.yml | 静态检查+编译校验，禁止版本递增/Release |
| push 到非main分支 | pr-check.yml | 同上 |

## 版本号规范

- 格式：`主版本.次版本.补丁号`（三段纯数字）
- 补丁位范围：0~9，满9自动进位
- 进位规则：
  - `1.0.9` → `1.1.0`
  - `1.9.9` → `2.0.0`
  - `16.17.27` → `16.18.0`（历史补丁位>9强制进位）
- 版本号由 CI 自动递增，**禁止在 PR 中手动修改**

## 制品规范

- IPA 文件名：`WebViewBrowser-unsigned-v{版本号}.ipa`
- 签名状态：**未签名**，供全能签本地重签名
- 元数据文件：`build-metadata.json`（版本、commit、SHA256、构建时间、耗时）
- Artifact 保留：30天自动清理
- Release 状态：**Draft 草稿**，人工审核后手动发布

## 本地调试脚本

```bash
# 运行版本递增单元测试
bash scripts/version-bump-test.sh

# 本地测试版本递增（会修改Info.plist）
bash scripts/version-bump.sh WebViewBrowser/Info.plist

# 测试README更新日志插入
bash scripts/update-readme.sh README.md 1.0.0 abc1234 "2026-01-01" "sha256hash" "测试更新"

# 测试制品元数据生成
bash scripts/generate-metadata.sh 1.0.0 abc1234 "2026-01-01T00:00:00Z" 120 WebViewBrowser.ipa metadata.json
```
