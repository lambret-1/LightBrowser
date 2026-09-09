#!/usr/bin/env bash
# =============================================================================
# 轻量浏览器 - 构建制品元数据生成脚本
# 生成 build-metadata.json，包含版本、commit、时间、SHA256、构建耗时
# =============================================================================
set -euo pipefail

VERSION="${1:?版本号不能为空}"
COMMIT_HASH="${2:?Commit哈希不能为空}"
BUILD_TIME="${3:?构建时间不能为空}"
BUILD_DURATION="${4:-0}"
IPA_PATH="${5:?IPA路径不能为空}"
OUTPUT_PATH="${6:-build-metadata.json}"

# 计算 SHA256
if [ -f "$IPA_PATH" ]; then
    IPA_SHA256=$(shasum -a 256 "$IPA_PATH" | awk '{print $1}')
    IPA_SIZE=$(stat -f%z "$IPA_PATH" 2>/dev/null || stat -c%s "$IPA_PATH" 2>/dev/null || echo "0")
    IPA_NAME=$(basename "$IPA_PATH")
else
    IPA_SHA256="FILE_NOT_FOUND"
    IPA_SIZE="0"
    IPA_NAME=$(basename "$IPA_PATH")
fi

# 生成 JSON
cat > "$OUTPUT_PATH" <<EOF
{
  "project": "LightBrowser",
  "version": "${VERSION}",
  "commit": "${COMMIT_HASH}",
  "build_time": "${BUILD_TIME}",
  "build_duration_seconds": ${BUILD_DURATION},
  "artifact": {
    "name": "${IPA_NAME}",
    "size_bytes": ${IPA_SIZE},
    "sha256": "${IPA_SHA256}"
  },
  "build_environment": {
    "runner_os": "macOS",
    "sdk": "iphoneos",
    "signing": "unsigned (for 全能签 re-sign)"
  }
}
EOF

echo "制品元数据已生成: $OUTPUT_PATH"
cat "$OUTPUT_PATH"
