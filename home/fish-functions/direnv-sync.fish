#!/usr/bin/env fish

set -g OP_ITEM_NAME "direnv"
set -g OP_ITEM_VAULT "Nix"

function push_envrc
    set -l path (pwd)
    set -l remote "$(op item get "$OP_ITEM_NAME" --vault "$OP_ITEM_VAULT" --field "$path" --format json | jq -j .value)"

    if test ! -f "$path/.envrc"
        echo "No .envrc file found in $path"
        return 1
    end

    echo -ne "$remote" | difft --check-only --exit-code - "$path/.envrc" >/dev/null
    if test $status -eq 0
        set_color green
        echo "✓ Up to date!"
        set_color normal
        return 0
    end

    echo -ne "$remote" | difft --exit-code - "$path/.envrc"

    read -P "Override remote? (Ctrl-c to abort)" || return 0

    op item edit --vault "$OP_ITEM_VAULT" "$OP_ITEM_NAME" "$path""[string]=$(cat "$path/.envrc")"

    if test $status -ne 0
        echo "Failed to update 1Password field for '$key'."
    end

    set_color green
    echo -n "↑ Pushed: "
    set_color normal
    echo "wrote remote field '$key' with $path/.envrc"
end

function pull_envrc
    set -l path (pwd)
    set -l remote "$(op item get "$OP_ITEM_NAME" --vault "$OP_ITEM_VAULT" --field "$path" --format json | jq -j .value)"

    if test -f "$path/.envrc"
        echo -ne "$remote" | difft --check-only --exit-code "$path/.envrc" - >/dev/null

        if test $status -eq 0
            set_color green
            echo "✓ Up to date!"
            set_color normal
            return 0
        end

        # Show what will change locally if we overwrite .envrc with remote
        echo -ne "$remote" | difft --override "*:bash" --exit-code "$path/.envrc" -

        read -P "Override local? (Ctrl-c to abort)" || return 0
    end

    echo -ne "$remote" > "$path/.envrc"

    set_color green
    echo -n "↓ Pulled: "
    set_color normal
    echo "read remote field '$key' to $path/.envrc"
end

function usage
    echo "Usage: "(status filename)" (push|pull)"
    echo "  push  - update 1Password field for (pwd) with contents of ./$ENVRC_FILE"
    echo "  pull  - update ./$ENVRC_FILE with contents of 1Password field for (pwd)"
end

# --- main ---
set -l subcmd $argv[1]

switch "$subcmd"
    case push
        push_envrc
    case pull
        pull_envrc
    case '*'
        usage
        test -n "$subcmd"; and return 64; or return 0
end
