# 轻量浏览器 - CI/CD 运维与故障排查手册

## 流水线总览

```
push to main
    │
    ▼
┌─────────────────────────────────────────┐
│ Job 1: prebuild（前置校验与版本递增）    │
│  ├─ 脚本权限校验                         │
│  ├─ 版本递增单元测试（25用例）           │
│  ├─ 版本格式合法性校验                   │
│  ├─ 执行版本递增                         │
│  └─ 提交版本变更到 main                  │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Job 2: build（iOS编译打包）              │
│  ├─ 构建环境信息输出                     │
│  ├─ SwiftLint 静态检查（不阻断）         │
│  ├─ xcodebuild 编译（未签名）            │
│  ├─ 打包 IPA                             │
│  └─ 上传 Artifact                        │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Job 3: release（制品元数据与Draft）      │
│  ├─ 下载 IPA Artifact                    │
│  ├─ 生成 build-metadata.json             │
│  ├─ 计算 SHA256                          │
│  ├─ 检查 Tag 冲突                        │
│  ├─ 创建 Git Tag                         │
│  ├─ 更新 README 更新日志                 │
│  └─ 创建 Draft Release（上传IPA+元数据） │
└─────────────────────────────────────────┘
```

## 常见故障排查

### 1. 版本递增单元测试失败

**现象**：Job 1 在"版本递增逻辑单元测试"步骤失败

**排查**：
```bash
# 本地运行单元测试查看详细输出
bash scripts/version-bump-test.sh
```

**常见原因**：
- 修改了 `version-bump.sh` 中的 `bump_version` 函数但未同步测试脚本
- 进位逻辑错误（补丁位≥9时次版本处理）

**修复**：确保 `scripts/version-bump.sh` 和 `scripts/version-bump-test.sh` 中的 `bump_version` 函数完全一致。

---

### 2. 版本格式非法

**现象**：报错 `版本格式非法: xxx（必须是三段数字）`

**原因**：Info.plist 中的版本号不是 `x.y.z` 三段纯数字格式

**修复**：手动修正 Info.plist 中的 `CFBundleShortVersionString` 为合法格式

---

### 3. 编译失败

**现象**：Job 2 编译步骤报错 `编译存在错误`

**排查**：
1. 下载 `build.log` 查看具体错误
2. 常见原因：
   - 新增 Swift 文件未注册到 `project.pbxproj`
   - 语法错误（可选值解包、类型不匹配）
   - pbxproj 文件损坏（JSON parse error）

**pbxproj 损坏修复**：
- 检查是否有重复的 ID 定义
- 检查 PBXBuildFile / PBXFileReference / PBXGroup / PBXSourcesBuildPhase 四处注册是否完整
- 恢复到上一个可编译版本的 pbxproj

---

### 4. Tag 已存在

**现象**：Job 3 报错 `Tag vX.Y.Z 已存在，终止流水线`

**原因**：同版本号重复触发构建

**处理**：
- 如果是误触发：删除远程 tag `git push origin :vX.Y.Z`，重新运行
- 如果是新版本：检查版本递增是否正常工作

---

### 5. Draft Release 创建失败（403）

**现象**：`Resource not accessible by integration`

**原因**：workflow 缺少 `contents: write` 权限

**修复**：确保 `build.yml` 顶层有：
```yaml
permissions:
  contents: write
```

---

### 6. IPA 文件找不到

**现象**：`APP包不存在: build/DerivedData/Build/Products/Release-iphoneos/WebViewBrowser.app`

**排查**：
1. 检查 scheme 名称是否正确
2. 检查编译配置是否为 Release
3. 查看编译日志是否有 `BUILD SUCCEEDED`

---

### 7. README 更新日志插入位置错误

**现象**：日志没有插入到正确位置

**原因**：README 中没有 `## 当前版本：` 这一行

**修复**：确保 README.md 包含 `## 当前版本：vX.Y.Z` 行，脚本会在该行之后插入新日志

## 版本进位逻辑调试

### 核心函数
```bash
bump_version() {
    local ver="$1"
    local major minor patch
    IFS='.' read -r major minor patch <<< "$ver"
    if [ "$patch" -ge 9 ]; then
        patch=0
        if [ "$minor" -eq 9 ]; then
            minor=0
            major=$((major + 1))
        else
            minor=$((minor + 1))
        fi
    else
        patch=$((patch + 1))
    fi
    echo "${major}.${minor}.${patch}"
}
```

### 边界用例
| 输入 | 输出 | 说明 |
|------|------|------|
| 1.0.0 | 1.0.1 | 正常递增 |
| 1.0.9 | 1.1.0 | 补丁进位 |
| 1.9.9 | 2.0.0 | 补丁+次版本进位 |
| 9.9.9 | 10.0.0 | 全进位 |
| 16.17.27 | 16.18.0 | 历史补丁>9强制进位 |

## Flutter 打包注意事项

> 本项目为纯 Swift + Xcode 项目，不使用 Flutter。以下为通用 iOS 打包注意事项。

1. **未签名打包参数**：
   ```
   CODE_SIGN_IDENTITY=""
   CODE_SIGNING_REQUIRED=NO
   CODE_SIGNING_ALLOWED=NO
   ```

2. **IPA 结构要求**（全能签兼容）：
   - Payload/ 目录下必须是 `.app` 包
   - `.app` 内包含完整的 Info.plist、二进制、资源
   - 不能有 `CodeResources`、`_CodeSignature` 等签名文件

3. **最低部署目标**：iOS 15.0

## 制品校验

### SHA256 校验
```bash
# 下载 IPA 后执行
shasum -a 256 WebViewBrowser-unsigned-vX.Y.Z.ipa
# 对比 Release 页面或 build-metadata.json 中的 sha256 值
```

### 元数据 JSON 结构
```json
{
  "project": "LightBrowser",
  "version": "x.y.z",
  "commit": "abc1234",
  "build_time": "2026-01-01T00:00:00Z",
  "build_duration_seconds": 120,
  "artifact": {
    "name": "WebViewBrowser-unsigned-vx.y.z.ipa",
    "size_bytes": 1824277,
    "sha256": "..."
  }
}
```

## Draft Release 使用指引

1. 流水线完成后，进入 GitHub Releases 页面
2. 找到标记为 `Draft` 的 Release
3. 审核：
   - 版本号是否正确
   - IPA 是否可下载
   - SHA256 是否完整
   - 更新日志是否准确
4. 确认无误后点击 `Edit` → `Publish release`
5. 发布后 App 内自动更新检测可识别到新版本
