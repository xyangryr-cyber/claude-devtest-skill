#!/bin/bash
# ============================================================
# Claude Code 研发测试闭环 一键安装脚本
# 项目主页：https://github.com/GITHUB_USERNAME/claude-devtest-skill
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "================================================"
echo "  Claude Code 研发测试闭环 安装脚本"
echo "================================================"
echo ""

# 1. 检查 Claude Code 是否安装
if ! command -v claude &> /dev/null; then
  error "未找到 claude 命令。请先安装 Claude Code：https://claude.ai/download"
fi
info "Claude Code 已安装"

# 2. 安装目录
SKILL_DIR="$HOME/Desktop/硅基员工/工作技能/研发测试闭环"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

mkdir -p "$SKILL_DIR"
mkdir -p "$HOOKS_DIR"
info "目录已创建"

# 3. 复制技能文件
cp "$(dirname "$0")/skill/SKILL.md" "$SKILL_DIR/"
cp "$(dirname "$0")/skill/pattern_devtest_loop.md" "$SKILL_DIR/"
info "技能文件已安装 → $SKILL_DIR"

# 4. 复制并赋权 hook 脚本
cp "$(dirname "$0")/hooks/mark_dev_session.sh" "$HOOKS_DIR/"
cp "$(dirname "$0")/hooks/trigger_devtest.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/mark_dev_session.sh"
chmod +x "$HOOKS_DIR/trigger_devtest.sh"
info "Hook 脚本已安装 → $HOOKS_DIR"

# 5. 更新 settings.json（合并，不覆盖现有配置）
if [ ! -f "$SETTINGS" ]; then
  # 如果 settings.json 不存在，创建最小配置
  cat > "$SETTINGS" << 'SETTINGS_EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/mark_dev_session.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/trigger_devtest.sh"
          }
        ]
      }
    ]
  }
}
SETTINGS_EOF
  info "settings.json 已创建并配置 hooks"
else
  # 检查是否已经有 hooks 配置
  if grep -q "mark_dev_session" "$SETTINGS" 2>/dev/null; then
    warn "Hook 已存在于 settings.json，跳过（不重复写入）"
  else
    warn "你的 settings.json 已存在，请手动添加以下内容到 \"hooks\" 字段："
    echo ""
    cat << 'MANUAL_EOF'
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/mark_dev_session.sh" }]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/trigger_devtest.sh" }]
      }
    ]
  }
MANUAL_EOF
    echo ""
    warn "文件路径：$SETTINGS"
  fi
fi

echo ""
echo "================================================"
info "安装完成！"
echo ""
echo "使用方法："
echo "  在 Claude Code 对话中说："
echo "  「用研发测试闭环实现 [功能描述]，项目路径 [你的项目路径]」"
echo ""
echo "或者让 Claude 改完代码后，下次对话自动触发测试（无需任何操作）"
echo "================================================"
echo ""
