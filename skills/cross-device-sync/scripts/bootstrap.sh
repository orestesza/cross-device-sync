#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# bootstrap.sh — 将任意项目初始化/改造成 cross-device-sync (Level 1 / 2 / 3)
# 安全原则：绝不覆盖目标项目已有的 AGENTS.md / STATUS.md / .gitignore 等文档
# 用法：
#   ./bootstrap.sh --target <dir> --level <1|2|3> \
#     [--remote-mode single|dual] \
#     [--artifact-backend rclone|rsync|manual] \
#     [--artifact-remote <remote>] \
#     [--name <project_name>] \
#     [--dry-run]
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TPL_DIR="${SKILL_DIR}/templates"

TARGET_DIR=""
LEVEL=""
REMOTE_MODE="single"
ARTIFACT_BACKEND="rclone"
ARTIFACT_REMOTE=""
PROJECT_NAME=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)           TARGET_DIR="$2"; shift 2 ;;
    --level)            LEVEL="$2"; shift 2 ;;
    --remote-mode)      REMOTE_MODE="$2"; shift 2 ;;
    --artifact-backend) ARTIFACT_BACKEND="$2"; shift 2 ;;
    --artifact-remote)  ARTIFACT_REMOTE="$2"; shift 2 ;;
    --name)             PROJECT_NAME="$2"; shift 2 ;;
    --dry-run)          DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '4,14p' "$0"
      exit 0
      ;;
    *)
      echo "❌ 未知参数: $1"
      exit 1
      ;;
  esac
done

if [[ -z "${TARGET_DIR}" || -z "${LEVEL}" ]]; then
  echo "❌ 必须指定 --target <dir> 和 --level <1|2|3>"
  exit 1
fi

case "${LEVEL}" in
  1|2|3) ;;
  *) echo "❌ --level 仅支持 1 / 2 / 3"; exit 1 ;;
esac

case "${REMOTE_MODE}" in
  single|dual) ;;
  *) echo "❌ --remote-mode 仅支持 single / dual"; exit 1 ;;
esac

case "${ARTIFACT_BACKEND}" in
  rclone|rsync|manual) ;;
  *) echo "❌ --artifact-backend 仅支持 rclone / rsync / manual"; exit 1 ;;
esac

if [[ -z "${PROJECT_NAME}" ]]; then
  PROJECT_NAME="$(basename "${TARGET_DIR}")"
fi

if [[ -z "${ARTIFACT_REMOTE}" && "${LEVEL}" -ge 2 && "${ARTIFACT_BACKEND}" == "rclone" ]]; then
  ARTIFACT_REMOTE="gdrive:AgentArtifacts/${PROJECT_NAME}"
fi

TODAY="$(date +%Y-%m-%d)"
SECRET_GUARD_MODE="basic"
[[ "${LEVEL}" == "3" ]] && SECRET_GUARD_MODE="strict"

echo "=== cross-device-sync Bootstrap ==="
echo "Target           : ${TARGET_DIR}"
echo "Project Name     : ${PROJECT_NAME}"
echo "Level            : L${LEVEL}"
echo "Remote Mode      : ${REMOTE_MODE}"
if [[ "${LEVEL}" -ge 2 ]]; then
  echo "Artifact Backend : ${ARTIFACT_BACKEND}"
  echo "Artifact Remote  : ${ARTIFACT_REMOTE:-<unset>}"
fi
echo "Dry-Run          : ${DRY_RUN}"
echo ""

write_if_missing() {
  local src="$1"
  local dst="$2"
  local exec_bit="${3:-0}"

  if [[ -e "${dst}" ]]; then
    echo "  [skip-exists] ${dst}（保留原文件，未覆盖）"
    return 0
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "  [create] ${dst} <- $(basename "${src}")"
    return 0
  fi

  mkdir -p "$(dirname "${dst}")"
  sed -e "s|__PROJECT_NAME__|${PROJECT_NAME}|g" \
      -e "s|__DATE__|${TODAY}|g" \
      -e "s|__LEVEL__|${LEVEL}|g" \
      -e "s|__REMOTE_MODE__|${REMOTE_MODE}|g" \
      -e "s|__ARTIFACT_BACKEND__|${ARTIFACT_BACKEND}|g" \
      -e "s|__ARTIFACT_REMOTE__|${ARTIFACT_REMOTE}|g" \
      "${src}" > "${dst}"

  if [[ "${exec_bit}" -eq 1 ]]; then
    chmod +x "${dst}"
  fi
  echo "  ✅ [created] ${dst}"
}

append_gitignore() {
  local tpl="$1"
  local dst="${TARGET_DIR}/.gitignore"
  local marker="# >>> cross-device-sync (L${LEVEL}) >>>"

  if [[ -f "${dst}" ]] && grep -Fq "${marker}" "${dst}"; then
    echo "  [skip-exists] ${dst} 已包含 L${LEVEL} 忽略规则"
    return 0
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    if [[ -f "${dst}" ]]; then
      echo "  [append] ${dst} <- $(basename "${tpl}")"
    else
      echo "  [create] ${dst} <- $(basename "${tpl}")"
    fi
    return 0
  fi

  mkdir -p "${TARGET_DIR}"
  {
    [[ -f "${dst}" ]] && echo ""
    echo "${marker}"
    cat "${tpl}"
    echo "# <<< cross-device-sync (L${LEVEL}) <<<"
  } >> "${dst}"
  echo "  ✅ [updated] ${dst}"
}

write_sync_config() {
  local dst="${TARGET_DIR}/.sync-config"
  if [[ -e "${dst}" ]]; then
    echo "  [skip-exists] ${dst}（保留原配置，未覆盖）"
    return 0
  fi
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "  [create] ${dst}"
    return 0
  fi
  mkdir -p "${TARGET_DIR}"
  cat > "${dst}" <<EOF
# cross-device-sync configuration
SYNC_LEVEL=${LEVEL}
REMOTE_MODE=${REMOTE_MODE}
SYNC_PRIMARY_REMOTE=origin
SYNC_BACKUP_REMOTE=backup
SYNC_SSH_TIMEOUT=8
SECRET_GUARD_MODE=${SECRET_GUARD_MODE}
MAX_FILE_MB=20
ARTIFACT_BACKEND=${ARTIFACT_BACKEND}
ARTIFACT_REMOTE=${ARTIFACT_REMOTE}
EOF
  echo "  ✅ [created] ${dst}"
}

# Core files (All Levels)
write_sync_config
write_if_missing "${TPL_DIR}/AGENTS.L${LEVEL}.md" "${TARGET_DIR}/AGENTS.md" 0
write_if_missing "${TPL_DIR}/STATUS.L${LEVEL}.md" "${TARGET_DIR}/STATUS.md" 0
write_if_missing "${SCRIPT_DIR}/sync.sh" "${TARGET_DIR}/scripts/sync.sh" 1
write_if_missing "${SCRIPT_DIR}/secret-guard.sh" "${TARGET_DIR}/scripts/secret-guard.sh" 1
append_gitignore "${TPL_DIR}/gitignore.L${LEVEL}"

# Initial log file
LOG_FILE="${TARGET_DIR}/logs/${TODAY}.md"
if [[ ! -e "${LOG_FILE}" ]]; then
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "  [create] ${LOG_FILE}"
  else
    mkdir -p "${TARGET_DIR}/logs"
    cat > "${LOG_FILE}" <<EOF
# ${TODAY} 变更记录

- 初始化 \`${PROJECT_NAME}\` 跨设备同步骨架（\`cross-device-sync\` Level ${LEVEL}，远端模式：\`${REMOTE_MODE}\`）。
EOF
    echo "  ✅ [created] ${LOG_FILE}"
  fi
else
  echo "  [skip-exists] ${LOG_FILE}"
fi

# Level 2 & 3 additions: artifacts manifest + artifact-sync.sh + .env.example
if [[ "${LEVEL}" -ge 2 ]]; then
  write_if_missing "${TPL_DIR}/manifest.yaml" "${TARGET_DIR}/artifacts/manifest.yaml" 0
  write_if_missing "${SCRIPT_DIR}/artifact-sync.sh" "${TARGET_DIR}/scripts/artifact-sync.sh" 1
  if [[ ! -e "${TARGET_DIR}/.env.example" ]]; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "  [create] ${TARGET_DIR}/.env.example"
    else
      cat > "${TARGET_DIR}/.env.example" <<'EOF'
# 本机环境变量模板（复制为 .env.local 使用，.env.local 严禁提交）
# TOOLCHAIN_DIR=/path/to/local/toolchain
EOF
      echo "  ✅ [created] ${TARGET_DIR}/.env.example"
    fi
  fi
fi

# Level 3 additions: allowlist placeholder
if [[ "${LEVEL}" -eq 3 ]]; then
  if [[ ! -e "${TARGET_DIR}/.secret-guard-allowlist" ]]; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "  [create] ${TARGET_DIR}/.secret-guard-allowlist"
    else
      cat > "${TARGET_DIR}/.secret-guard-allowlist" <<'EOF'
# 每行填写一个经用户明确批准留在私有仓的受控文件相对路径（禁止通配符）
EOF
      echo "  ✅ [created] ${TARGET_DIR}/.secret-guard-allowlist"
    fi
  fi
fi

echo ""
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "🔍 Dry-Run 预览完成，未修改任何文件。确认后去掉 --dry-run 执行。"
else
  echo "✅ Bootstrap 完成！下一步建议："
  echo "   1. 若尚未初始化 Git：cd \"${TARGET_DIR}\" && git init -b main"
  echo "   2. 绑定远端：git remote add origin <SSH_URL>（双远程再加 git remote add backup <SSH_URL>）"
  echo "   3. 检查并提交：./scripts/secret-guard.sh && git add . && git commit -m 'chore: bootstrap cross-device-sync L${LEVEL}'"
fi
