#!/bin/bash
# Install atlassian_sync into a BMAD project
set -eu

TARGET_DIR="${1:-.}"
SKILL_DIR="$TARGET_DIR/.claude/skills/bmad-atlassian-sync"
TOOLS_DIR="$TARGET_DIR/.claude/tools/atlassian-sync"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Installing atlassian_sync into $TARGET_DIR..."

# Copy BMAD skill files
mkdir -p "$SKILL_DIR"
cp -r "$SCRIPT_DIR/bmad-integration/skills/bmad-atlassian-sync/"* "$SKILL_DIR/"
echo "  Copied skill files to $SKILL_DIR"

# Copy sync engine (TypeScript + Python bridge + bundled Python API client)
mkdir -p "$TOOLS_DIR"
cp -r "$SCRIPT_DIR/src" "$TOOLS_DIR/"
cp "$SCRIPT_DIR/package.json" "$TOOLS_DIR/"
cp "$SCRIPT_DIR/tsconfig.json" "$TOOLS_DIR/"
echo "  Copied sync engine to $TOOLS_DIR"

# Install Node dependencies
echo "  Installing dependencies..."
cd "$TOOLS_DIR" && npm install --omit=dev 2>/dev/null
echo "  Dependencies installed"

# Copy .env example if no .env exists
if [ ! -f "$TARGET_DIR/.env" ]; then
  cp "$SCRIPT_DIR/.env.example" "$TARGET_DIR/.env.atlassian.example"
  echo "  Created .env.atlassian.example"
fi

echo ""
echo "Done! Next steps:"
echo "  1. Copy .env.atlassian.example to .env and fill in credentials"
echo "  2. Add atlassian_sync config to _bmad/bmm/config.yaml:"
echo "       atlassian_sync: enabled"
echo "       jira_project_key: YOUR_PROJECT_KEY"
echo "       jira_board_id: YOUR_BOARD_ID"
echo "       confluence_space_key: YOUR_SPACE_KEY"
echo ""
echo "  See: $SCRIPT_DIR/bmad-integration/config/ for full config examples"
