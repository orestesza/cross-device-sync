#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# artifact-sync.sh — Level 2/3 大文件外部存储同步与 SHA-256 校验脚本
# 支持后端：
#   rclone (推荐，原生对接 Google Drive 5TB / S3 / WebDAV / SFTP，无需桌面 App)
#   rsync  (直连 NAS / Tailscale 节点)
#   manual (仅本地 SHA-256 校验，手动下载/上传)
#
# 用法：
#   ./scripts/artifact-sync.sh list               列出 manifest.yaml 已登记产物
#   ./scripts/artifact-sync.sh hash <file>        计算文件大小与 SHA-256（供写入 manifest.yaml）
#   ./scripts/artifact-sync.sh verify             核对本地 artifacts/ 文件与 manifest.yaml SHA-256
#   ./scripts/artifact-sync.sh push [--dry-run]   将本地 artifacts/ 上传至外部存储
#   ./scripts/artifact-sync.sh pull [--dry-run]   从外部存储拉取大文件并自动校验
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SYNC_REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
ARTIFACTS_DIR="${PROJECT_ROOT}/artifacts"
MANIFEST_FILE="${ARTIFACTS_DIR}/manifest.yaml"

ARTIFACT_BACKEND="${ARTIFACT_BACKEND:-rclone}"
ARTIFACT_REMOTE="${ARTIFACT_REMOTE:-}"

if [[ -f "${PROJECT_ROOT}/.sync-config" ]]; then
  while IFS='=' read -r k v; do
    k="$(printf '%s' "${k}" | tr -d '[:space:]')"
    [[ -z "${k}" || "${k}" == \#* ]] && continue
    v="${v%%#*}"
    v="$(printf '%s' "${v}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
    case "${k}" in
      ARTIFACT_BACKEND) ARTIFACT_BACKEND="${v}" ;;
      ARTIFACT_REMOTE)  ARTIFACT_REMOTE="${v}" ;;
    esac
  done < "${PROJECT_ROOT}/.sync-config"
fi

calc_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "❌ 未找到 shasum 或 sha256sum" >&2
    exit 1
  fi
}

cmd_hash() {
  local target="${1:-}"
  if [[ -z "${target}" || ! -f "${target}" ]]; then
    echo "用法: $0 hash <file_path>"
    exit 1
  fi
  local size sha rel abs_target
  size="$(wc -c < "${target}" | tr -d '[:space:]')"
  sha="$(calc_sha256 "${target}")"
  abs_target="$(cd "$(dirname "${target}")" && pwd)/$(basename "${target}")"
  rel="${abs_target#${ARTIFACTS_DIR}/}"
  rel="${rel#./artifacts/}"
  rel="${rel#artifacts/}"
  cat <<EOF
  - path: "${rel}"
    size_bytes: ${size}
    sha256: "${sha}"
    version: "1.0.0"
    notes: ""
EOF
}

# Parse simple manifest.yaml entries via python3 (macOS built-in) for reliability
parse_manifest() {
  python3 - "${MANIFEST_FILE}" <<'PY'
import sys, re

path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
except FileNotFoundError:
    sys.exit(0)

entries = []
cur = {}
for raw in lines:
    line = raw.strip()
    if not line or line.startswith('#'):
        continue
    if line.startswith('- '):
        if cur:
            entries.append(cur)
        cur = {}
        line = line[2:].strip()
    m = re.match(r'^([a-zA-Z0-9_]+)\s*:\s*(.*)$', line)
    if m:
        k, v = m.group(1), m.group(2).strip()
        if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
            v = v[1:-1]
        cur[k] = v
if cur:
    entries.append(cur)

for e in entries:
    if 'path' in e and e['path']:
        print(f"{e.get('path','')}\t{e.get('sha256','')}\t{e.get('size_bytes','')}\t{e.get('version','')}\t{e.get('notes','')}")
PY
}

cmd_list() {
  if [[ ! -f "${MANIFEST_FILE}" ]]; then
    echo "ℹ️  尚未创建 ${MANIFEST_FILE}"
    exit 0
  fi
  echo "=== Artifacts Manifest (backend=${ARTIFACT_BACKEND}, remote=${ARTIFACT_REMOTE:-<unset>}) ==="
  local count=0
  while IFS=$'\t' read -r p sha sz ver notes; do
    [[ -z "${p}" ]] && continue
    count=$((count + 1))
    local status="⬜ 缺失"
    if [[ -f "${ARTIFACTS_DIR}/${p}" ]]; then
      status="✅ 本地存在"
    fi
    echo "  [${status}] ${p} (ver=${ver:-n/a}, size=${sz:-n/a}B, sha256=${sha:0:12}...) ${notes}"
  done < <(parse_manifest)
  if [[ "${count}" -eq 0 ]]; then
    echo "  (manifest.yaml 暂无登记条目)"
  fi
}

cmd_verify() {
  if [[ ! -f "${MANIFEST_FILE}" ]]; then
    echo "ℹ️  未找到 ${MANIFEST_FILE}，跳过校验"
    exit 0
  fi
  local total=0 failed=0
  while IFS=$'\t' read -r p sha sz ver notes; do
    [[ -z "${p}" ]] && continue
    total=$((total + 1))
    local full="${ARTIFACTS_DIR}/${p}"
    if [[ ! -f "${full}" ]]; then
      echo "❌ 缺失文件: artifacts/${p}"
      failed=$((failed + 1))
      continue
    fi
    if [[ -n "${sha}" ]]; then
      local actual
      actual="$(calc_sha256 "${full}")"
      if [[ "${actual}" != "${sha}" ]]; then
        echo "❌ SHA-256 不匹配: artifacts/${p}"
        echo "   expected: ${sha}"
        echo "   actual  : ${actual}"
        failed=$((failed + 1))
        continue
      fi
    fi
    echo "✅ 校验通过: artifacts/${p}"
  done < <(parse_manifest)

  if [[ "${total}" -eq 0 ]]; then
    echo "ℹ️  manifest.yaml 暂无登记条目"
    exit 0
  fi
  if [[ "${failed}" -gt 0 ]]; then
    echo "❌ 共 ${failed}/${total} 项校验失败"
    exit 1
  fi
  echo "✅ 全部 ${total} 项大文件校验通过"
}

require_remote() {
  if [[ -z "${ARTIFACT_REMOTE}" ]]; then
    echo "❌ 未配置 ARTIFACT_REMOTE，请先在 .sync-config 中设置（例如 ARTIFACT_REMOTE=gdrive:AgentArtifacts/<project>）"
    exit 1
  fi
}

cmd_push() {
  local dry_run="${1:-}"
  mkdir -p "${ARTIFACTS_DIR}"
  case "${ARTIFACT_BACKEND}" in
    rclone)
      require_remote
      if ! command -v rclone >/dev/null 2>&1; then
        echo "❌ 未安装 rclone。请运行: brew install rclone && rclone config"
        exit 1
      fi
      local flags=(--progress --exclude "manifest.yaml" --exclude ".gitkeep" --exclude ".DS_Store")
      [[ "${dry_run}" == "--dry-run" ]] && flags+=(--dry-run)
      echo "⬆️  [rclone] 上传 artifacts/ -> ${ARTIFACT_REMOTE}"
      rclone copy "${ARTIFACTS_DIR}" "${ARTIFACT_REMOTE}" "${flags[@]}"
      echo "✅ [rclone] 上传完成"
      ;;
    rsync)
      require_remote
      local flags=(-avh --progress --exclude="manifest.yaml" --exclude=".gitkeep" --exclude=".DS_Store")
      [[ "${dry_run}" == "--dry-run" ]] && flags+=(--dry-run)
      echo "⬆️  [rsync] 上传 artifacts/ -> ${ARTIFACT_REMOTE}/"
      rsync "${flags[@]}" "${ARTIFACTS_DIR}/" "${ARTIFACT_REMOTE}/"
      echo "✅ [rsync] 上传完成"
      ;;
    manual)
      echo "ℹ️  当前为 manual 模式：请手动上传大文件至网盘/Cloudreve，并确认 manifest.yaml 中的 SHA-256 已更新。"
      cmd_verify
      ;;
    *)
      echo "❌ 不支持的 ARTIFACT_BACKEND: ${ARTIFACT_BACKEND}"
      exit 1
      ;;
  esac
}

cmd_pull() {
  local dry_run="${1:-}"
  mkdir -p "${ARTIFACTS_DIR}"
  case "${ARTIFACT_BACKEND}" in
    rclone)
      require_remote
      if ! command -v rclone >/dev/null 2>&1; then
        echo "❌ 未安装 rclone。请运行: brew install rclone && rclone config"
        exit 1
      fi
      local flags=(--progress --exclude "manifest.yaml" --exclude ".gitkeep" --exclude ".DS_Store")
      [[ "${dry_run}" == "--dry-run" ]] && flags+=(--dry-run)
      echo "⬇️  [rclone] 拉取 ${ARTIFACT_REMOTE} -> artifacts/"
      rclone copy "${ARTIFACT_REMOTE}" "${ARTIFACTS_DIR}" "${flags[@]}"
      if [[ "${dry_run}" != "--dry-run" ]]; then
        cmd_verify
      fi
      ;;
    rsync)
      require_remote
      local flags=(-avh --progress --exclude="manifest.yaml" --exclude=".gitkeep" --exclude=".DS_Store")
      [[ "${dry_run}" == "--dry-run" ]] && flags+=(--dry-run)
      echo "⬇️  [rsync] 拉取 ${ARTIFACT_REMOTE}/ -> artifacts/"
      rsync "${flags[@]}" "${ARTIFACT_REMOTE}/" "${ARTIFACTS_DIR}/"
      if [[ "${dry_run}" != "--dry-run" ]]; then
        cmd_verify
      fi
      ;;
    manual)
      echo "ℹ️  当前为 manual 模式：请按 artifacts/manifest.yaml 中的说明下载文件后校验："
      cmd_verify
      ;;
    *)
      echo "❌ 不支持的 ARTIFACT_BACKEND: ${ARTIFACT_BACKEND}"
      exit 1
      ;;
  esac
}

case "${1:-list}" in
  list)   cmd_list ;;
  hash)   cmd_hash "${2:-}" ;;
  verify) cmd_verify ;;
  push)   cmd_push "${2:-}" ;;
  pull)   cmd_pull "${2:-}" ;;
  *)
    echo "用法: $0 {list|hash <file>|verify|push [--dry-run]|pull [--dry-run]}"
    exit 1
    ;;
esac
