function __agentty_state_file
    echo "$HOME/.cache/agentty/state.json"
end

function __agentty_state_load
    set -l state_file (__agentty_state_file)
    set -l dir (pwd)

    # Defaults
    set -gx AGENTTY_SESSION_ID ""
    set -gx AGENTTY_SESSION (basename $dir)
    set -gx AGENTTY_MODEL "sonnet"
    set -gx AGENTTY_MODE "edit"
    set -gx AGENTTY_PROVIDER "claude"

    if not test -f "$state_file"
        return 0
    end

    # Read state for current directory
    set -l dir_state (jq -r --arg dir "$dir" '.dirs[$dir] // empty' "$state_file" 2>/dev/null)
    if test -z "$dir_state"
        return 0
    end

    set -l val

    set val (echo "$dir_state" | jq -r '.session_id // empty')
    test -n "$val" && set -gx AGENTTY_SESSION_ID "$val"

    set val (echo "$dir_state" | jq -r '.session_name // empty')
    test -n "$val" && set -gx AGENTTY_SESSION "$val"

    set val (echo "$dir_state" | jq -r '.model // empty')
    test -n "$val" && set -gx AGENTTY_MODEL "$val"

    set val (echo "$dir_state" | jq -r '.mode // empty')
    test -n "$val" && set -gx AGENTTY_MODE "$val"

    set val (echo "$dir_state" | jq -r '.provider // empty')
    test -n "$val" && set -gx AGENTTY_PROVIDER "$val"
end

function __agentty_state_save
    set -l state_file (__agentty_state_file)
    set -l dir (pwd)

    # Ensure cache directory exists
    mkdir -p (dirname "$state_file")

    # Create base state if file doesn't exist
    if not test -f "$state_file"
        echo '{"version":1,"dirs":{}}' > "$state_file"
    end

    # Build dir entry and merge into state
    set -l timestamp (date -Iseconds)
    set -l updated (jq -c \
        --arg dir "$dir" \
        --arg sid "$AGENTTY_SESSION_ID" \
        --arg sname "$AGENTTY_SESSION" \
        --arg model "$AGENTTY_MODEL" \
        --arg mode "$AGENTTY_MODE" \
        --arg provider "$AGENTTY_PROVIDER" \
        --arg ts "$timestamp" \
        '.dirs[$dir] = {
            session_id: $sid,
            session_name: $sname,
            model: $model,
            mode: $mode,
            provider: $provider,
            updated_at: $ts
        }' "$state_file")

    echo "$updated" > "$state_file"
end

function __agentty_state_new_session
    set -gx AGENTTY_SESSION_ID (uuidgen)
    set -gx AGENTTY_SESSION (basename (pwd))
    __agentty_state_save
end

function __agentty_state_clear_env
    set -e AGENTTY_ACTIVE
    set -e AGENTTY_SESSION_ID
    set -e AGENTTY_SESSION
    set -e AGENTTY_MODEL
    set -e AGENTTY_MODE
    set -e AGENTTY_PROVIDER
end
