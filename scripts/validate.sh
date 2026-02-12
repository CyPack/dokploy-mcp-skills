#!/usr/bin/env bash
# Dokploy MCP Skills - Setup Validation
# Usage: bash scripts/validate.sh
# Checks: Docker, Node.js, Claude Code, Dokploy API, MCP config, Skill files

set -euo pipefail

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  \033[32m[PASS]\033[0m $1"; ((PASS++)); }
fail() { echo -e "  \033[31m[FAIL]\033[0m $1"; ((FAIL++)); }
warn() { echo -e "  \033[33m[WARN]\033[0m $1"; ((WARN++)); }

echo ""
echo "=== Dokploy MCP Skills - Setup Validation ==="
echo ""

# --- 1. Docker ---
echo "--- Docker ---"
if command -v docker &>/dev/null; then
    if docker info &>/dev/null 2>&1; then
        pass "Docker is running ($(docker --version | grep -oP '\d+\.\d+\.\d+'))"
    else
        fail "Docker installed but not running"
    fi
else
    fail "Docker not installed"
fi

# --- 2. Node.js ---
echo "--- Node.js ---"
if command -v node &>/dev/null; then
    NODE_VERSION=$(node --version | grep -oP '\d+' | head -1)
    if [ "$NODE_VERSION" -ge 18 ]; then
        pass "Node.js >= 18 ($(node --version))"
    else
        fail "Node.js < 18 ($(node --version)), need 18+"
    fi
else
    fail "Node.js not installed"
fi

# --- 3. Claude Code CLI ---
echo "--- Claude Code ---"
if command -v claude &>/dev/null; then
    pass "Claude Code CLI found"
else
    fail "Claude Code CLI not found (install: npm install -g @anthropic-ai/claude-code)"
fi

# --- 4. Dokploy API ---
echo "--- Dokploy API ---"
DOKPLOY_URL="${DOKPLOY_URL:-http://localhost:3000}"
if curl -sf "${DOKPLOY_URL}/api" -o /dev/null --connect-timeout 5 2>/dev/null; then
    pass "Dokploy API responding at ${DOKPLOY_URL}"
else
    warn "Dokploy API not responding at ${DOKPLOY_URL} (is Dokploy running?)"
fi

if [ -n "${DOKPLOY_API_KEY:-}" ]; then
    HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
        "${DOKPLOY_URL}/api/project.all" \
        -H "x-api-key: ${DOKPLOY_API_KEY}" \
        --connect-timeout 5 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        pass "API key is valid (project.all returned 200)"
    else
        fail "API key invalid or API unreachable (HTTP ${HTTP_CODE})"
    fi
else
    warn "DOKPLOY_API_KEY not set in environment (can't validate API key)"
fi

# --- 5. MCP Config ---
echo "--- MCP Config ---"
CLAUDE_CONFIG="$HOME/.claude.json"
if [ -f "$CLAUDE_CONFIG" ]; then
    pass "Claude config exists at ${CLAUDE_CONFIG}"
    if grep -q "DokployServer" "$CLAUDE_CONFIG" 2>/dev/null; then
        pass "DokployServer entry found in config"
        if grep -q "enable-tools" "$CLAUDE_CONFIG" 2>/dev/null; then
            pass "Compose tools enabled (--enable-tools found)"
        else
            warn "Compose tools may not be enabled (--enable-tools not found)"
        fi
    else
        fail "DokployServer not found in ${CLAUDE_CONFIG}"
    fi
else
    fail "Claude config not found at ${CLAUDE_CONFIG}"
fi

# --- 6. Skill Files ---
echo "--- Skill Files ---"
SKILL_DIR="$HOME/.claude/skills/dokploy-manage"
if [ -d "$SKILL_DIR" ]; then
    pass "Skill directory exists"
    if [ -f "$SKILL_DIR/SKILL.md" ]; then
        pass "SKILL.md exists"
    else
        fail "SKILL.md missing from ${SKILL_DIR}"
    fi
    if [ -d "$SKILL_DIR/references" ]; then
        pass "References directory exists"
        for ref in setup-guide.md tool-reference.md workflow-examples.md; do
            if [ -f "$SKILL_DIR/references/$ref" ]; then
                pass "  $ref found"
            else
                fail "  $ref missing"
            fi
        done
    else
        fail "References directory missing from ${SKILL_DIR}"
    fi
else
    fail "Skill directory not found at ${SKILL_DIR}"
fi

# --- Summary ---
echo ""
echo "=== Summary ==="
echo -e "  \033[32mPASS: ${PASS}\033[0m"
[ "$WARN" -gt 0 ] && echo -e "  \033[33mWARN: ${WARN}\033[0m"
[ "$FAIL" -gt 0 ] && echo -e "  \033[31mFAIL: ${FAIL}\033[0m"

if [ "$FAIL" -eq 0 ]; then
    echo ""
    echo "All checks passed! Your setup is ready."
    exit 0
else
    echo ""
    echo "Some checks failed. See guides/troubleshooting.md for help."
    exit 1
fi
