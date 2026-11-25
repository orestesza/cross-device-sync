#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# sync.sh — 跨设备 Git 同步脚本（单远程 / 主备双远程自适应）
# 用法：
#   ./scripts/sync.sh status     检查远程连通性与分支差异
#   ./scripts/sync.sh pull       拉取最新提交（双远程时主不可达自动降级走 backup）
#   ./scripts/sync.sh push       安全守卫校验后推送（双远程时主不可达自动降级走 backup）
#   ./scripts/sync.sh reconcile  [双远程] 主节点恢复后双向合并对齐 origin 与 backup
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SYNC_REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

REMOTE_MODE="${REMOTE_MODE:-auto}"
PRIMARY_REMOTE="${SYNC_PRIMARY_REMOTE:-origin}"
BACKUP_REMOTE="${SYNC_BACKUP_REMOTE:-backup}"
SSH_TIMEOUT="${SYNC_SSH_TIMEOUT:-8}"

if [[ -f "${PROJECT_ROOT}/.sync-config" ]]; then
  while IFS='=' read -r k v; do
    k="$(printf '%s' "${k}" | tr -d '[:space:]')"
    [[ -z "${k}" || "${k}" == \#* ]] && continue
    v="${v%%#*}"
    v="$(printf '%s' "${v}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
    case "${k}" in
      REMOTE_MODE)         REMOTE_MODE="${v}" ;;
      SYNC_PRIMARY_REMOTE) PRIMARY_REMOTE="${v}" ;;
      SYNC_BACKUP_REMOTE)  BACKUP_REMOTE="${v}" ;;
      SYNC_SSH_TIMEOUT)    SSH_TIMEOUT="${v}" ;;
    esac
  done < "${PROJECT_ROOT}/.sync-config"
fi

export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o ConnectTimeout=${SSH_TIMEOUT} -o BatchMode=yes}"

cd "${PROJECT_ROOT}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ 当前目录不是 Git 仓库: ${PROJECT_ROOT}"
  exit 1
fi

BRANCH="${SYNC_BRANCH:-$(git symbolic-ref --short HEAD 2>/dev/null || echo main)}"

remote_exists() {
  git remote get-url "$1" >/dev/null 2>&1
}

# Resolve effective remote mode
if [[ "${REMOTE_MODE}" == "auto" ]]; then
  if remote_exists "${BACKUP_REMOTE}"; then
    REMOTE_MODE="dual"
  else
    REMOTE_MODE="single"
  fi
fi

probe_remote() {
  local remote="$1"
  if ! remote_exists "$remote"; then
    return 1
  fi
  git ls-remote "$remote" >/dev/null 2>&1
}

ensure_clean_worktree() {
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "❌ 工作区存在未提交改动，请先 commit 或 stash 后再同步："
    git status --short
    exit 1
  fi
}

run_secret_guard() {
  if [[ -x "${SCRIPT_DIR}/secret-guard.sh" ]]; then
    "${SCRIPT_DIR}/secret-guard.sh"
  elif [[ -f "${SCRIPT_DIR}/secret-guard.sh" ]]; then
    bash "${SCRIPT_DIR}/secret-guard.sh"
  else
    local bad_files
    bad_files="$(git ls-files | grep -E '(^|/)(id_(rsa|ed25519|ecdsa|dsa)$|.*\.(pem|key|p12|pfx)$|.*_(ed25519|rsa)$|\.env$)' || true)"
    if [[ -n "${bad_files}" ]]; then
      echo "🚨 安全拦截：检测到疑似私钥或 .env 文件已被 Git 跟踪，已中止推送！"
      echo "${bad_files}"
      exit 1
    fi
  fi
}

cmd_status() {
  echo "=== Git 同步状态 (mode: ${REMOTE_MODE}, branch: ${BRANCH}) ==="
  local local_sha
  local_sha="$(git rev-parse --short HEAD 2>/dev/null || echo '<no-commits>')"
  echo "Local HEAD : ${local_sha}"

  local remotes=("${PRIMARY_REMOTE}")
  if [[ "${REMOTE_MODE}" == "dual" ]]; then
    remotes+=("${BACKUP_REMOTE}")
  fi

  for r in "${remotes[@]}"; do
    if ! remote_exists "$r"; then
      echo "Remote ${r} : ❌ 未配置"
      continue
    fi
    local url
    url="$(git remote get-url "$r")"
    if probe_remote "$r"; then
      local r_sha
      r_sha="$(git ls-remote "$r" "refs/heads/${BRANCH}" 2>/dev/null | awk '{print substr($1,1,7)}')"
      r_sha="${r_sha:-<empty>}"
      echo "Remote ${r} : ✅ 在线 (${r_sha}) — ${url}"
    else
      echo "Remote ${r} : ⚠️ 不可达 — ${url}"
    fi
  done
}

cmd_pull() {
  ensure_clean_worktree
  if probe_remote "${PRIMARY_REMOTE}"; then
    echo "⬇️  远程 (${PRIMARY_REMOTE}) 在线，正在拉取 ${BRANCH}..."
    if git ls-remote --exit-code "${PRIMARY_REMOTE}" "refs/heads/${BRANCH}" >/dev/null 2>&1; then
      git pull --rebase "${PRIMARY_REMOTE}" "${BRANCH}"
      echo "✅ 已从 ${PRIMARY_REMOTE} 同步完成"
    else
      echo "ℹ️  远程 ${PRIMARY_REMOTE} 尚未有 ${BRANCH} 分支，跳过 pull"
    fi
  elif [[ "${REMOTE_MODE}" == "dual" ]] && probe_remote "${BACKUP_REMOTE}"; then
    echo "⚠️  主远程 (${PRIMARY_REMOTE}) 不可达！自动降级从备用远程 (${BACKUP_REMOTE}) 拉取..."
    if git ls-remote --exit-code "${BACKUP_REMOTE}" "refs/heads/${BRANCH}" >/dev/null 2>&1; then
      git pull --rebase "${BACKUP_REMOTE}" "${BRANCH}"
      echo "✅ 已从备用远程 (${BACKUP_REMOTE}) 拉取完成（主节点恢复后请运行 ./scripts/sync.sh reconcile）"
    else
      echo "ℹ️  备用远程尚未有 ${BRANCH} 分支，跳过 pull"
    fi
  else
    echo "❌ 远程不可达！请检查网络连接或 git remote 配置。"
    exit 1
  fi
}

cmd_push() {
  run_secret_guard
  if probe_remote "${PRIMARY_REMOTE}"; then
    echo "⬆️  远程 (${PRIMARY_REMOTE}) 在线，正在推送 ${BRANCH}..."
    git push -u "${PRIMARY_REMOTE}" "${BRANCH}"
    echo "✅ 已推送至 ${PRIMARY_REMOTE}"
    if [[ "${REMOTE_MODE}" == "dual" && "${SYNC_PUSH_BOTH:-0}" == "1" ]] && probe_remote "${BACKUP_REMOTE}"; then
      echo "⬆️  SYNC_PUSH_BOTH=1 已启用，同步直推备用远程 (${BACKUP_REMOTE})..."
      git push "${BACKUP_REMOTE}" "${BRANCH}"
      echo "✅ 已直推至备用远程 (${BACKUP_REMOTE})"
    fi
  elif [[ "${REMOTE_MODE}" == "dual" ]] && probe_remote "${BACKUP_REMOTE}"; then
    echo "⚠️  主远程 (${PRIMARY_REMOTE}) 不可达！自动降级推送至备用远程 (${BACKUP_REMOTE})..."
    git push -u "${BACKUP_REMOTE}" "${BRANCH}"
    echo "✅ 已应急推送至备用远程 (${BACKUP_REMOTE})"
    echo "📌 提醒：主远程恢复在线后，请执行 ./scripts/sync.sh reconcile 对齐双远程"
  else
    echo "❌ 远程不可达！本地提交已安全保留，待联网后重试。"
    exit 1
  fi
}

cmd_reconcile() {
  if [[ "${REMOTE_MODE}" != "dual" ]]; then
    echo "ℹ️  当前为单远程模式 (REMOTE_MODE=${REMOTE_MODE})，无需 reconcile。"
    exit 0
  fi
  ensure_clean_worktree
  run_secret_guard
  echo "🔄 正在检查主/备双远程连通性..."
  if ! probe_remote "${PRIMARY_REMOTE}"; then
    echo "❌ 主远程 (${PRIMARY_REMOTE}) 仍不可达，无法执行 reconcile"
    exit 1
  fi
  if ! probe_remote "${BACKUP_REMOTE}"; then
    echo "❌ 备用远程 (${BACKUP_REMOTE}) 不可达，无法执行 reconcile"
    exit 1
  fi

  git fetch "${PRIMARY_REMOTE}"
  git fetch "${BACKUP_REMOTE}"

  if git show-ref --verify --quiet "refs/remotes/${PRIMARY_REMOTE}/${BRANCH}"; then
    echo "🔀 合并 ${PRIMARY_REMOTE}/${BRANCH}..."
    git merge --no-edit "${PRIMARY_REMOTE}/${BRANCH}"
  fi
  if git show-ref --verify --quiet "refs/remotes/${BACKUP_REMOTE}/${BRANCH}"; then
    echo "🔀 合并 ${BACKUP_REMOTE}/${BRANCH}..."
    git merge --no-edit "${BACKUP_REMOTE}/${BRANCH}"
  fi

  echo "⬆️  双向推送对齐 ${PRIMARY_REMOTE} 与 ${BACKUP_REMOTE}..."
  git push -u "${PRIMARY_REMOTE}" "${BRANCH}"
  git push "${BACKUP_REMOTE}" "${BRANCH}"

  local sha_p sha_b sha_l
  sha_l="$(git rev-parse --short HEAD)"
  sha_p="$(git ls-remote "${PRIMARY_REMOTE}" "refs/heads/${BRANCH}" | awk '{print substr($1,1,7)}')"
  sha_b="$(git ls-remote "${BACKUP_REMOTE}" "refs/heads/${BRANCH}" | awk '{print substr($1,1,7)}')"
  echo "✅ 双远程已对齐！Local=${sha_l} | ${PRIMARY_REMOTE}=${sha_p} | ${BACKUP_REMOTE}=${sha_b}"
}

case "${1:-status}" in
  status)    cmd_status ;;
  pull)      cmd_pull ;;
  push)      cmd_push ;;
  reconcile) cmd_reconcile ;;
  *)
    echo "用法: $0 {status|pull|push|reconcile}"
    exit 1
    ;;
esac
