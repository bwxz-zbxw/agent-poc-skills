#!/usr/bin/env bash
# POC Skills 一键安装脚本（跨平台：TRAE / OpenCode / Claude / Agents / DSH）
# 将本仓库 skills/ 下的每个 skill 目录安装到对应平台的 skills 目录下。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/skills"

# ---- 各平台 skills 目录（全局）。可用同名环境变量覆盖，例如 TRAE_DIR=~/.my-trae/skills ----
TRAE_DIR="${TRAE_DIR:-$HOME/.trae-cn/skills}"
OPENCODE_DIR="${OPENCODE_DIR:-$HOME/.config/opencode/skills}"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude/skills}"
AGENTS_DIR="${AGENTS_DIR:-$HOME/.agents/skills}"
DSH_DIR=""
if [ -n "${DSH_HOME:-}" ]; then DSH_DIR="$DSH_HOME/skills"; fi

LINK=0
PLATFORM="all"

usage() {
  cat <<'EOF'
用法: ./install.sh [--platform <名称>] [--symlink]

把本仓库的 skills 安装到指定平台的 skills 目录（默认 all = 全部可用平台）。

平台: trae, opencode, claude, agents, dsh, all

选项:
  --platform <name>  只安装指定平台（可用逗号分隔多个，如 trae,opencode）
  --symlink          用软链接代替复制（更新仓库后自动生效）
  -h, --help         显示本帮助

各平台目标目录（同名环境变量可覆盖）:
  trae     -> $TRAE_DIR
  opencode -> $OPENCODE_DIR
  claude   -> $CLAUDE_DIR
  agents   -> $AGENTS_DIR    （.agents 通用规范，OpenCode / Claude 均兼容）
  dsh      -> $DSH_DIR       （需设置 DSH_HOME 环境变量，否则跳过）
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --platform=*) PLATFORM="${1#*=}" ;;
    --platform) PLATFORM="$2"; shift ;;
    --symlink|-l) LINK=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

if [ ! -d "$SRC_DIR" ]; then
  echo "错误: 找不到 skills 目录: $SRC_DIR" >&2
  exit 1
fi

# ---- 本地数据文件保护：更新时不覆盖这些路径，保留用户本地改动 ----
PRESERVE_DIRS=("poc-capability/deployments" "poc-case/cases")
PRESERVE_FILES=("poc-capability/capabilities.yaml")

should_preserve() {
  local rel="$1"
  for d in "${PRESERVE_DIRS[@]}"; do
    if [[ "$rel" == "$d" || "$rel" == "$d/"* ]]; then return 0; fi
  done
  for f in "${PRESERVE_FILES[@]}"; do
    if [[ "$rel" == "$f" ]]; then return 0; fi
  done
  return 1
}

copy_incremental() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  while IFS= read -r -d '' src_file; do
    local rel="${src_file#"$src"}"
    if should_preserve "$rel" && [ -e "$dst/$rel" ]; then
      echo "  保留本地文件: $rel"
      continue
    fi
    mkdir -p "$(dirname "$dst/$rel")"
    cp "$src_file" "$dst/$rel"
  done < <(find "$src" -type f -print0)
}

install_to() {
  local dest="$1" platform="$2"
  if [ -z "$dest" ]; then
    echo "跳过 [$platform]：目标目录未配置"
    return
  fi
  mkdir -p "$dest"
  local count=0
  for skill in "$SRC_DIR"/*/; do
    local name
    name="$(basename "$skill")"
    if [ "$LINK" -eq 1 ]; then
      rm -rf "$dest/$name"
      ln -s "$skill" "$dest/$name"
    elif [ -e "$dest/$name" ]; then
      # 更新：逐文件覆盖，命中「不覆盖清单」的本地文件保留
      copy_incremental "$skill" "$dest/$name"
    else
      # 首次安装：整目录复制（含清单模板，供首次填写）
      cp -R "$skill" "$dest/$name"
    fi
    count=$((count + 1))
  done
  echo "已安装 [$platform] $count 个 skill -> $dest"
}

install_platform() {
  case "$1" in
    trae) install_to "$TRAE_DIR" "trae" ;;
    opencode) install_to "$OPENCODE_DIR" "opencode" ;;
    claude) install_to "$CLAUDE_DIR" "claude" ;;
    agents) install_to "$AGENTS_DIR" "agents" ;;
    dsh) install_to "$DSH_DIR" "dsh" ;;
    *) echo "未知平台: $1" >&2; exit 1 ;;
  esac
}

if [ "$PLATFORM" = "all" ]; then
  install_platform trae
  install_platform opencode
  install_platform claude
  install_platform agents
  install_platform dsh
else
  IFS=',' read -ra NAMES <<< "$PLATFORM"
  for n in "${NAMES[@]}"; do
    install_platform "$n"
  done
fi

echo ""
echo "完成。卸载只需删除上述目标目录中对应的 poc-* 目录。"