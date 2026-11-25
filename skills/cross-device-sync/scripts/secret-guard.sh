#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# secret-guard.sh — Git 推送前敏感文件 / 大文件体积 / 凭据内容防误提交守卫
# 读取项目根目录 .sync-config（可选）：
#   SYNC_LEVEL=1|2|3
#   SECRET_GUARD_MODE=basic|strict
#   MAX_FILE_MB=20
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SYNC_REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

cd "${PROJECT_ROOT}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ 当前目录不是 Git 仓库: ${PROJECT_ROOT}"
  exit 1
fi

# Load optional .sync-config safely (simple KEY=VALUE lines only)
SYNC_LEVEL=1
SECRET_GUARD_MODE="basic"
MAX_FILE_MB=20

if [[ -f "${PROJECT_ROOT}/.sync-config" ]]; then
  while IFS='=' read -r k v; do
    k="$(printf '%s' "${k}" | tr -d '[:space:]')"
    [[ -z "${k}" || "${k}" == \#* ]] && continue
    v="${v%%#*}"
    v="$(printf '%s' "${v}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
    case "${k}" in
      SYNC_LEVEL)        SYNC_LEVEL="${v}" ;;
      SECRET_GUARD_MODE) SECRET_GUARD_MODE="${v}" ;;
      MAX_FILE_MB)       MAX_FILE_MB="${v}" ;;
    esac
  done < "${PROJECT_ROOT}/.sync-config"
fi

# Level 3 defaults to strict if not explicitly overridden
if [[ "${SYNC_LEVEL}" == "3" && "${SECRET_GUARD_MODE}" == "basic" ]]; then
  SECRET_GUARD_MODE="strict"
fi

ALLOWLIST_FILE="${PROJECT_ROOT}/.secret-guard-allowlist"

is_allowlisted() {
  local f="$1"
  if [[ ! -f "${ALLOWLIST_FILE}" ]]; then
    return 1
  fi
  grep -Fxq -- "${f}" "${ALLOWLIST_FILE}"
}

# Collect all tracked + staged files (deduplicated)
FILES_LIST="$(
  {
    git ls-files
    git diff --cached --name-only --diff-filter=ACMR
  } | sort -u
)"

ERRORS=0

while IFS= read -r file; do
  [[ -z "${file}" ]] && continue
  [[ ! -f "${file}" ]] && continue

  if is_allowlisted "${file}"; then
    continue
  fi

  # 1) Filename guard (all levels): private keys, .env, rclone.conf
  base="$(basename "${file}")"
  if [[ "${base}" != ".env.example" && "${base}" != ".env.sample" && "${base}" != ".env.template" ]]; then
    if printf '%s\n' "${file}" | grep -Eq '(^|/)(id_(rsa|ed25519|ecdsa|dsa)$|.*\.(pem|key|p12|pfx)$|.*_(ed25519|rsa)$|\.env(\..+)?$|rclone\.conf$)'; then
      echo "🚨 [Filename Guard] 拦截疑似私钥或本地凭据文件: ${file}"
      ERRORS=$((ERRORS + 1))
    fi
  fi

  # 2) Size guard (Level 2 & 3, or whenever MAX_FILE_MB > 0 and level >= 2)
  if [[ "${SYNC_LEVEL}" -ge 2 && "${MAX_FILE_MB}" -gt 0 ]]; then
    size_bytes="$(wc -c < "${file}" | tr -d '[:space:]')"
    max_bytes=$((MAX_FILE_MB * 1024 * 1024))
    if [[ "${size_bytes}" -gt "${max_bytes}" ]]; then
      size_mb=$(( (size_bytes + 1048575) / 1048576 ))
      echo "🚨 [Size Guard] 文件超过 ${MAX_FILE_MB}MB 阈值 (${size_mb}MB): ${file}"
      echo "   -> 请将其移入 artifacts/、登记到 artifacts/manifest.yaml，并用 ./scripts/artifact-sync.sh push 同步至外部存储。"
      ERRORS=$((ERRORS + 1))
    fi
  fi

  # 3) Strict content guard (Level 3 / SECRET_GUARD_MODE=strict)
  if [[ "${SECRET_GUARD_MODE}" == "strict" ]]; then
    # Skip self script and templates/docs describing patterns
    if [[ "${file}" == "scripts/secret-guard.sh" || "${file}" == */secret-guard.sh ]]; then
      continue
    fi
    # Only scan text files (grep -I skips binary)
    if grep -Iq . "${file}" 2>/dev/null; then
      if grep -Eq -- '-----BEGIN ([A-Z0-9 ]+ )?PRIVATE KEY-----' "${file}"; then
        echo "🚨 [Strict Guard] 检测到私钥头内容: ${file}"
        ERRORS=$((ERRORS + 1))
      fi
      if grep -Eq -- '(ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{20,})' "${file}"; then
        echo "🚨 [Strict Guard] 检测到疑似明文 API Token/Key: ${file}"
        ERRORS=$((ERRORS + 1))
      fi
    fi
  fi
done <<< "${FILES_LIST}"

if [[ "${ERRORS}" -gt 0 ]]; then
  echo "❌ secret-guard 检查未通过（共 ${ERRORS} 项拦截）。请清理后重试；如为经批准的私有仓受控文件，可将其精确路径加入 .secret-guard-allowlist。"
  exit 1
fi

echo "✅ secret-guard 检查通过 (Level=${SYNC_LEVEL}, Mode=${SECRET_GUARD_MODE}, MaxFile=${MAX_FILE_MB}MB)"
