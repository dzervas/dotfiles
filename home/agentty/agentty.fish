function agentty_toggle
    if test "$AGENTTY_ACTIVE" = "1"
        # Turn off: restore default Enter, clear env
        bind \r execute
        bind \n execute
        __agentty_state_clear_env
    else
        # Turn on: load state, set active, override Enter
        __agentty_state_load
        set -gx AGENTTY_ACTIVE 1
        bind \r __agentty_accept_line
        bind \n __agentty_accept_line
    end
end

function agentty_mode_cycle
    if test "$AGENTTY_ACTIVE" != "1"
        return
    end

    switch $AGENTTY_MODE
        case edit
            set -gx AGENTTY_MODE "plan"
        case plan
            set -gx AGENTTY_MODE "read-only"
        case '*'
            set -gx AGENTTY_MODE "edit"
    end

    __agentty_state_save
end

function agentty_new_session
    if test "$AGENTTY_ACTIVE" != "1"
        return
    end

    __agentty_state_new_session
end

function __agentty_accept_line
    set -l prompt (commandline)

    # Empty input: just execute (normal newline behavior)
    if test -z (string trim "$prompt")
        commandline -f execute
        return
    end

    # Add to fish history
    builtin history merge
    builtin history append -- "$prompt"

    # Clear the commandline and print what was typed
    commandline ""
    echo

    # Run the prompt through the active provider
    __agentty_run_prompt "$prompt"
    set -l run_status $status

    # Pause on any error-like outcome so the message is visible before redraw.
    # Set AGENTTY_HOLD_ON_ERROR=0 to disable.
    if test $run_status -ne 0; or test "$AGENTTY_LAST_IS_ERROR" = "1"
        if test "$AGENTTY_HOLD_ON_ERROR" != "0"
            printf '%s(Agentty error shown above; press Enter to continue)%s\n' (set_color yellow) (set_color normal) > /dev/tty
            read -l _ < /dev/tty
        end
    end

    # Add spacing so final output isn't immediately overwritten by prompt
    echo
    commandline -f repaint
end

function __agentty_run_prompt --argument-names prompt
    set -l provider $AGENTTY_PROVIDER
    if test -z "$provider"
        set provider "claude"
    end

    set -l run_fn "__agentty_provider_"$provider"_run"
    set -l resume_fn "__agentty_provider_"$provider"_resume"

    # Fish runs the last command in a pipeline in the current shell,
    # so set -g inside __agentty_render_stream will persist
    $run_fn "$prompt" | __agentty_render_stream
    set -l run_status $status

    if test $run_status -ne 0
        printf '%sAgentty error: provider exited with status %s%s\n' (set_color red) "$run_status" (set_color normal) > /dev/tty
        return $run_status
    end

    # Auto-recover from stale/deleted session IDs and retry once.
    if test "$AGENTTY_STALE_SESSION" = "1"
        printf '%sAgentty: session not found, starting a new session and retrying...%s\n' (set_color yellow) (set_color normal) > /dev/tty
        set -gx AGENTTY_SESSION_ID ""
        __agentty_state_save

        $run_fn "$prompt" | __agentty_render_stream
        set run_status $status

        if test $run_status -ne 0
            printf '%sAgentty error: retry failed with status %s%s\n' (set_color red) "$run_status" (set_color normal) > /dev/tty
            return $run_status
        end
    end

    # Handle follow-up if AskUserQuestion was detected
    if test -n "$AGENTTY_NEEDS_FOLLOWUP"
        set -l answer "$AGENTTY_NEEDS_FOLLOWUP"
        set -g AGENTTY_NEEDS_FOLLOWUP ""

        # Send the answer back via resume
        if test -n "$AGENTTY_SESSION_ID"
            $resume_fn "$AGENTTY_SESSION_ID" "$answer" | __agentty_render_stream
        end
    end

    # Save state (session_id may have been updated by init event)
    __agentty_state_save
end

function __agentty_on_pwd_change --on-variable PWD
    if test "$AGENTTY_ACTIVE" = "1"
        __agentty_state_load
    end
end
