#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# install-skills.sh — 将本仓库 skills/* 通过软链接同步安装到 Antigravity & Codex
# 用法：
#   ./scripts/install-skills.sh              安装/更新所有 skill 软链接
#   ./scripts/install-skills.sh --dry-run    仅预览将要创建的软链接
#   ./scripts/install-skills.sh --status     检查当前各 App 的软链接状态
#   ./scripts/install-skills.sh --uninstall  移除指向本仓库的软链接
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILLS_SRC_DIR="${REPO_ROOT}/skills"

TARGET_ROOTS=(
  "${HOME}/.gemini/config/skills"
  "${HOME}/.codex/skills"
)

MODE="install"
for arg in "$@"; do
  case "${arg}" in
    --dry-run)   MODE="dry-run" ;;
    --status)    MODE="status" ;;
    --uninstall) MODE="uninstall" ;;
    -h|--help)
      echo "用法: $0 [--dry-run|--status|--uninstall]"
      exit 0
      ;;
    *)
      echo "❌ 未知参数: ${arg}"
      exit 1
      ;;
  esac
done

if [[ ! -d "${SKILLS_SRC_DIR}" ]]; then
  echo "❌ 未找到 skills 目录: ${SKILLS_SRC_DIR}"
  exit 1
fi

skill_names=()
for d in "${SKILLS_SRC_DIR}"/*; do
  if [[ -d "${d}" && -f "${d}/SKILL.md" ]]; then
    skill_names+=("$(basename "${d}")")
  fi
done

if [[ ${#skill_names[@]} -eq 0 ]]; then
  echo "⚠️  ${SKILLS_SRC_DIR} 中没有包含 SKILL.md 的目录"
  exit 0
fi

for target_root in "${TARGET_ROOTS[@]}"; do
  echo "=== 目标目录: ${target_root} ==="
  for name in "${skill_names[@]}"; do
    src="${SKILLS_SRC_DIR}/${name}"
    dst="${target_root}/${name}"

    case "${MODE}" in
      status)
        if [[ -L "${dst}" ]]; then
          actual="$(readlink "${dst}")"
          if [[ "${actual}" == "${src}" ]]; then
            echo "  ✅ ${name} -> ${actual}"
          else
            echo "  ⚠️  ${name} 软链接指向其他路径: ${actual}"
          fi
        elif [[ -e "${dst}" ]]; then
          echo "  ⚠️  ${name} 存在非软链接文件/目录（受保护未覆盖）"
        else
          echo "  ⬜ ${name} 未安装"
        fi
        ;;
      dry-run)
        if [[ -L "${dst}" && "$(readlink "${dst}")" == "${src}" ]]; then
          echo "  [skip] ${name} 已正确链接"
        elif [[ -e "${dst}" && ! -L "${dst}" ]]; then
          echo "  [CONFLICT] ${dst} 已存在且非软链接，将拒绝覆盖"
        else
          echo "  [link] ${dst} -> ${src}"
        fi
        ;;
      install)
        mkdir -p "${target_root}"
        if [[ -L "${dst}" ]]; then
          actual="$(readlink "${dst}")"
          if [[ "${actual}" == "${src}" ]]; then
            echo "  ✅ ${name} 已链接（无需变更）"
          else
            ln -sfn "${src}" "${dst}"
            echo "  🔄 ${name} 已更新软链接 -> ${src}"
          fi
        elif [[ -e "${dst}" ]]; then
          echo "  ❌ 保护中止：${dst} 已存在实体目录/文件，请手动备份或移除后再运行"
          exit 1
        else
          ln -s "${src}" "${dst}"
          echo "  ✅ ${name} 已安装 -> ${src}"
        fi
        ;;
      uninstall)
        if [[ -L "${dst}" && "$(readlink "${dst}")" == "${src}" ]]; then
          rm "${dst}"
          echo "  🗑️  已移除软链接: ${dst}"
        else
          echo "  ⏭️  跳过（非本仓库软链接）: ${dst}"
        fi
        ;;
    esac
  done
done
