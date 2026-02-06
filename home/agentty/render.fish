function __agentty_render_stream
    # Reads normalized JSONL events from stdin, renders inline to terminal
    # Returns state via globals for caller logic
    set -g AGENTTY_NEEDS_FOLLOWUP ""
    set -g AGENTTY_ASK_TOOL_USE_ID ""
    set -g AGENTTY_LAST_IS_ERROR 0
    set -g AGENTTY_STALE_SESSION 0

    while read -l line
        test -z "$line" && continue

        set -l etype (echo "$line" | jq -r '.type // empty')

        switch "$etype"
            case init
                set -l sid (echo "$line" | jq -r '.session_id // empty')
                if test -n "$sid"
                    set -gx AGENTTY_SESSION_ID "$sid"
                end

            case text
                set -l content (echo "$line" | jq -r '.content // empty')
                if test -n "$content"
                    __agentty_render_text "$content"
                end

            case tool_start
                __agentty_render_tool_header "$line"

            case tool_result
                __agentty_render_tool_result "$line"

            case ask
                __agentty_render_ask "$line"

            case done
                set -l is_error (echo "$line" | jq -r '.is_error // false')
                if test "$is_error" = "true"
                    set -g AGENTTY_LAST_IS_ERROR 1
                    set -l errs (echo "$line" | jq -r '.errors[]?')
                    if string match -q '*No conversation found with session ID*' "$errs"
                        set -g AGENTTY_STALE_SESSION 1
                    end
                end
                __agentty_render_footer "$line"

            case error
                set -l msg (echo "$line" | jq -r '.message // "Unknown error"')
                printf '%s%s%s\n' (set_color red) "$msg" (set_color normal)
        end
    end
end

function __agentty_render_text --argument-names content
    # Render markdown-ish text inline with color
    printf '%s%s%s\n' (set_color normal) "$content" (set_color normal)
end

function __agentty_render_tool_header --argument-names event_json
    set -l name (echo "$event_json" | jq -r '.name // "Unknown"')
    set -l input (echo "$event_json" | jq -r '.input // {} | to_entries | map(.key + "=" + (.value | tostring | .[0:60])) | join(", ") | .[0:80]')

    printf '\n%s  %s%s' (set_color --bold cyan) "$name" (set_color normal)
    if test -n "$input"
        printf ' %s%s%s' (set_color --dim) "$input" (set_color normal)
    end
    printf '\n'
end

function __agentty_render_tool_result --argument-names event_json
    set -l content (echo "$event_json" | jq -r '.content // empty')
    if test -z "$content"
        return
    end

    # Truncate to ~10 lines
    set -l lines (string split \n "$content")
    set -l count (count $lines)
    set -l max_lines 10

    printf '%s' (set_color --dim)
    if test $count -le $max_lines
        printf '  %s\n' $lines
    else
        for i in (seq 1 $max_lines)
            printf '  %s\n' "$lines[$i]"
        end
        printf '  ... (%d more lines)%s\n' (math $count - $max_lines) (set_color normal)
    end
    printf '%s' (set_color normal)
end

function __agentty_render_ask --argument-names event_json
    # Render AskUserQuestion and collect user response
    set -g AGENTTY_ASK_TOOL_USE_ID (echo "$event_json" | jq -r '.tool_use_id // empty')

    set -l questions (echo "$event_json" | jq -c '.questions // []')
    set -l qcount (echo "$questions" | jq 'length')

    set -l answers ""

    for qi in (seq 0 (math $qcount - 1))
        set -l q (echo "$questions" | jq -c ".[$qi]")
        set -l question (echo "$q" | jq -r '.question // "?"')
        set -l options (echo "$q" | jq -r '.options // [] | .[].label')

        printf '\n%s  %s%s\n' (set_color --bold yellow) "$question" (set_color normal)

        if test -n "$options"
            set -l opts (string split \n "$options")
            set -l oi 1
            for opt in $opts
                printf '  %s%d)%s %s\n' (set_color --bold) $oi (set_color normal) "$opt"
                set oi (math $oi + 1)
            end
            printf '  %s%d)%s Other\n' (set_color --bold) $oi (set_color normal)

            read -P (printf '%s> %s' (set_color cyan) (set_color normal)) -l choice < /dev/tty

            # If numeric, map to option label
            if string match -qr '^\d+$' "$choice"
                set -l idx (math $choice)
                if test $idx -le (count $opts)
                    set choice "$opts[$idx]"
                end
            end

            set answers "$answers$choice"
        else
            read -P (printf '%s> %s' (set_color cyan) (set_color normal)) -l answer < /dev/tty
            set answers "$answers$answer"
        end
    end

    set -g AGENTTY_NEEDS_FOLLOWUP "$answers"
end

function __agentty_render_footer --argument-names event_json
    set -l cost (echo "$event_json" | jq -r '.cost_usd // 0')
    set -l duration (echo "$event_json" | jq -r '.duration_ms // 0')
    set -l turns (echo "$event_json" | jq -r '.num_turns // 0')
    set -l is_error (echo "$event_json" | jq -r '.is_error // false')

    # Convert duration to human-readable
    set -l secs (math "$duration / 1000")

    if test "$is_error" = "true"
        set -l subtype (echo "$event_json" | jq -r '.subtype // "error"')
        set -l errs (echo "$event_json" | jq -r '.errors[]?')

        printf '\n%sAgentty error (%s)%s\n' (set_color red) "$subtype" (set_color normal)
        if test -n "$errs"
            for err in (string split \n "$errs")
                printf '%s  - %s%s\n' (set_color red) "$err" (set_color normal)
            end
        end
    end

    printf '\n%s' (set_color --dim)
    printf '  $%.4f  %ss  %d turns%s\n' "$cost" "$secs" "$turns" (set_color normal)
end
