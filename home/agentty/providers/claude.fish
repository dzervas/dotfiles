function __agentty_provider_claude_run --argument-names prompt
    set -l cmd claude -p "$prompt" \
        --output-format stream-json \
        --verbose \
        --model $AGENTTY_MODEL

    if test "$AGENTTY_DEBUG" = "1"
        printf '%sAgentty cmd:%s %s\n' (set_color yellow) (set_color normal) (string join -- ' ' $cmd) > /dev/tty
    end

    # Resume existing session if we have one
    if test -n "$AGENTTY_SESSION_ID"
        set -a cmd --resume $AGENTTY_SESSION_ID
    end

    # Mode-specific flags
    switch $AGENTTY_MODE
        case plan
            set -a cmd --permission-mode plan
        case read-only
            set -a cmd --permission-mode plan \
                --disallowedTools "Edit,Write,Bash,NotebookEdit" \
                --allowedTools "Read,Glob,Grep,WebFetch,WebSearch"
    end

    # Keep stderr visible on /dev/tty so errors don't get eaten by the pipe
    $cmd 2> /dev/tty | __agentty_provider_claude_normalize
end

function __agentty_provider_claude_resume --argument-names session_id prompt
    claude -p "$prompt" \
        --output-format stream-json \
        --verbose \
        --model $AGENTTY_MODEL \
        --resume $session_id \
        2> /dev/tty | __agentty_provider_claude_normalize
end

function __agentty_provider_claude_supports --argument-names feature
    contains $feature sessions permissions modes streaming
end

function __agentty_provider_claude_normalize
    # Reads claude stream-json (JSONL) from stdin, emits normalized events to stdout
    while read -l line
        test -z "$line" && continue

        if test "$AGENTTY_DEBUG" = "1"
            printf '%sRAW:%s %s\n' (set_color --dim) (set_color normal) "$line" > /dev/tty
        end

        set -l etype (echo "$line" | jq -r '.type // empty')

        switch "$etype"
            case system
                set -l subtype (echo "$line" | jq -r '.subtype // empty')
                switch "$subtype"
                    case init
                        set -l sid (echo "$line" | jq -r '.session_id // empty')
                        echo '{"type":"init","session_id":"'$sid'"}'
                end

            case assistant
                # Parse content blocks from message
                set -l content_len (echo "$line" | jq '.message.content | length')
                for i in (seq 0 (math $content_len - 1))
                    set -l block (echo "$line" | jq -c ".message.content[$i]")
                    set -l btype (echo "$block" | jq -r '.type')

                    switch "$btype"
                        case text
                            set -l text (echo "$block" | jq -r '.text')
                            # Emit as normalized text event
                            echo "$block" | jq -c '{type: "text", content: .text}'

                        case tool_use
                            set -l tname (echo "$block" | jq -r '.name')
                            # Check if this is an AskUserQuestion tool
                            if string match -qi '*ask*' "$tname"; or string match -qi '*question*' "$tname"
                                echo "$block" | jq -c '{
                                    type: "ask",
                                    tool_use_id: .id,
                                    questions: .input.questions
                                }'
                            else
                                echo "$block" | jq -c '{
                                    type: "tool_start",
                                    tool_use_id: .id,
                                    name: .name,
                                    input: .input
                                }'
                            end
                    end
                end

            case user
                # Check for tool_result in user messages
                set -l content_len (echo "$line" | jq '.message.content | length // 0' 2>/dev/null)
                if test "$content_len" -gt 0 2>/dev/null
                    for i in (seq 0 (math $content_len - 1))
                        set -l block (echo "$line" | jq -c ".message.content[$i]")
                        set -l btype (echo "$block" | jq -r '.type // empty')
                        if test "$btype" = "tool_result"
                            echo "$block" | jq -c '{
                                type: "tool_result",
                                tool_use_id: .tool_use_id,
                                content: .content
                            }'
                        end
                    end
                end

            case result
                echo "$line" | jq -c '{
                    type: "done",
                    session_id: .session_id,
                    cost_usd: .total_cost_usd,
                    duration_ms: .duration_ms,
                    num_turns: .num_turns,
                    is_error: .is_error,
                    result: .result,
                    errors: (.errors // []),
                    subtype: (.subtype // "")
                }'
        end
    end
end
