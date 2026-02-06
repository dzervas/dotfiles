#!/usr/bin/env bash
# PreToolUse hook for agentty inline permission handling
# When AGENTTY_ACTIVE is set, prompts the user via /dev/tty
# When not set, exits 0 (no interference with normal claude usage)

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# If agentty is not active, don't interfere
if [[ -z "${AGENTTY_ACTIVE:-}" ]]; then
    exit 0
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')

# --- Policy: Auto-allow safe tools ---
SAFE_TOOLS="Read Glob Grep WebSearch WebFetch Task"
for safe in $SAFE_TOOLS; do
    if [[ "$TOOL_NAME" == "$safe" ]]; then
        exit 0
    fi
done

# --- Policy: Bash command analysis ---
if [[ "$TOOL_NAME" == "Bash" ]]; then
    CMD=$(echo "$TOOL_INPUT" | jq -r '.command // empty')

    # Auto-allow safe bash commands
    SAFE_PATTERNS=(
        "^git (status|diff|log|show|branch|remote|tag|rev-parse)"
        "^ls( |$)"
        "^pwd$"
        "^cat "
        "^head "
        "^tail "
        "^echo "
        "^test "
        "^jq "
        "^rg "
        "^fd "
        "^wc "
        "^sort "
        "^uniq "
        "^which "
        "^type "
        "^file "
        "^stat "
        "^basename "
        "^dirname "
        "^realpath "
        "^nix (eval|build|flake (show|metadata))"
        "^statix "
    )

    for pattern in "${SAFE_PATTERNS[@]}"; do
        if echo "$CMD" | grep -qE "$pattern"; then
            exit 0
        fi
    done

    # Auto-deny dangerous commands
    DENY_PATTERNS=(
        "rm -rf /"
        "mkfs"
        "dd if="
        ":\(\)\{.*\}.*;"
        "^sudo rm"
        "^sudo mkfs"
        "> /dev/sd"
    )

    for pattern in "${DENY_PATTERNS[@]}"; do
        if echo "$CMD" | grep -qF "$pattern" 2>/dev/null || echo "$CMD" | grep -qE "$pattern" 2>/dev/null; then
            cat <<DENY_JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Auto-denied: dangerous command pattern detected"
  }
}
DENY_JSON
            exit 0
        fi
    done
fi

# --- Ask user for everything else ---
# Render prompt to /dev/tty
{
    echo ""
    echo "┌ Permission Request ─────────────────────"
    echo "│ Tool: $TOOL_NAME"

    if [[ "$TOOL_NAME" == "Bash" ]]; then
        CMD=$(echo "$TOOL_INPUT" | jq -r '.command // empty')
        echo "│ Command: $CMD"
    elif [[ "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" ]]; then
        FILE=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // empty')
        echo "│ File: $FILE"
    else
        # Show a brief summary of input
        SUMMARY=$(echo "$TOOL_INPUT" | jq -r 'to_entries | map(.key + "=" + (.value | tostring | .[0:40])) | join(", ") | .[0:60]')
        if [[ -n "$SUMMARY" ]]; then
            echo "│ Args: $SUMMARY"
        fi
    fi

    echo "└─────────────────────────────────────────"
} > /dev/tty

# Read response from /dev/tty
printf "Allow? [Y/n]: " > /dev/tty
read -r RESPONSE < /dev/tty

case "${RESPONSE,,}" in
    n|no|deny)
        cat <<DENY_JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "User denied"
  }
}
DENY_JSON
        ;;
    *)
        # Allow (default on Enter or 'y')
        cat <<ALLOW_JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "User approved"
  }
}
ALLOW_JSON
        ;;
esac
