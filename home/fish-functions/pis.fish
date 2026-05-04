set -l unshared_env_vars \
	VAULT_TOKEN \
	AWS_ACCESS_KEY_ID \
	AWS_SECRET_ACCESS_KEY \
	AWS_SESSION_TOKEN \
	AWS_PROFILE \
	AZURE_CLIENT_ID \
	AZURE_CLIENT_SECRET \
	AZURE_TENANT_ID \
	CLOUDFLARE_API_TOKEN \
	DIGITALOCEAN_ACCESS_TOKEN \
	GITHUB_TOKEN \
	GH_TOKEN \
	GITLAB_TOKEN \
	GOOGLE_APPLICATION_CREDENTIALS \
	OPENAI_API_KEY \
	ANTHROPIC_API_KEY \
	GEMINI_API_KEY \
	SSH_AUTH_SOCK \
	GPG_AGENT_INFO \
	KRB5CCNAME

set -l bwrap_mounts
set -l pi_args
set -l index 1

while test $index -le (count $argv)
	set -l arg $argv[$index]

	switch $arg
		case --bind --ro-bind
			set -l flag $arg
			set index (math $index + 1)

			if test $index -gt (count $argv)
				echo (set_color red)"Error: $flag expects <host dir>:<target dir>"(set_color normal)
				return 1
			end

			set -l mount $argv[$index]
			set -l parts (string split -m1 : -- $mount)
			if test (count $parts) -ne 2; or test -z "$parts[1]"; or test -z "$parts[2]"
				echo (set_color red)"Error: $flag expects <host dir>:<target dir>"(set_color normal)
				return 1
			end

			set -l host_dir (string replace -r '^~(?=/|$)' $HOME -- $parts[1])
			set -l target_dir $parts[2]

			if test $flag = --bind
				set bwrap_mounts $bwrap_mounts --bind $host_dir $target_dir
			else
				set bwrap_mounts $bwrap_mounts --ro-bind $host_dir $target_dir
			end

		case '--bind=*' '--ro-bind=*'
			set -l split_arg (string split -m1 = -- $arg)
			set -l flag $split_arg[1]
			set -l mount $split_arg[2]
			set -l parts (string split -m1 : -- $mount)
			if test (count $parts) -ne 2; or test -z "$parts[1]"; or test -z "$parts[2]"
				echo (set_color red)"Error: $flag expects <host dir>:<target dir>"(set_color normal)
				return 1
			end

			set -l host_dir (string replace -r '^~(?=/|$)' $HOME -- $parts[1])
			set -l target_dir $parts[2]

			if test $flag = --bind
				set bwrap_mounts $bwrap_mounts --bind $host_dir $target_dir
			else
				set bwrap_mounts $bwrap_mounts --ro-bind $host_dir $target_dir
			end

		case --
			set index (math $index + 1)
			set pi_args $pi_args $argv[$index..-1]
			break

		case '*'
			set pi_args $pi_args $arg
	end

	set index (math $index + 1)
end

set -l project_dir (pwd)
set -l sandbox_id (printf '%s' $project_dir | sha256sum | cut -d' ' -f1)
set -l sandbox_home "$HOME/.cache/pi/sandboxes/$sandbox_id/home"
set -l dotfiles_extensions_dir "$HOME/Lab/dotfiles/pi/extensions"
set -l sandbox_extension "$dotfiles_extensions_dir/sandbox.ts"
mkdir -p $sandbox_home

if string match -q "$HOME/*" -- $project_dir
	set -l project_parent_in_home (string replace "$HOME/" '' -- (dirname $project_dir))
	mkdir -p "$sandbox_home/$project_parent_in_home"
end

set -l bwrap_env
for name in $unshared_env_vars
	set bwrap_env $bwrap_env --unsetenv $name
end

mkdir -p $sandbox_home/.pi/agent/extensions $sandbox_home/.config/{jj,git}

# --bind /nix/var/nix/daemon-socket /nix/var/nix/daemon-socket \
bwrap \
	--unshare-all \
	--share-net \
	--die-with-parent \
	--new-session \
	--proc /proc \
	--dev /dev \
	--tmpfs /tmp \
	--ro-bind /nix/store /nix/store \
	--ro-bind /etc/nix /etc/nix \
	--ro-bind /etc/static /etc/static \
	--ro-bind /etc/ssl /etc/ssl \
	--ro-bind /etc/resolv.conf /etc/resolv.conf \
	--ro-bind /etc/hosts /etc/hosts \
	--ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
	--ro-bind /etc/protocols /etc/protocols \
	--ro-bind /etc/services /etc/services \
	--ro-bind /etc/passwd /etc/passwd \
	--ro-bind /etc/group /etc/group \
	--ro-bind /run/current-system/sw /run/current-system/sw \
	--ro-bind /etc/profiles/per-user/$USER/ /etc/profiles/per-user/$USER/ \
	--bind $sandbox_home $HOME \
	--ro-bind $HOME/.pi $HOME/.pi \
	--ro-bind $HOME/Lab/dotfiles/pi/sandbox.ts $HOME/.pi/agent/sandbox.ts \
	--bind $project_dir $project_dir \
	--ro-bind $HOME/.config/jj $HOME/.config/jj \
	--ro-bind $HOME/.config/git $HOME/.config/git \
	$bwrap_mounts \
	$bwrap_env \
	--chdir $project_dir \
	--setenv HOME $HOME \
	--setenv CI 1 \
	-- \
	bash -lc 'pi --extension "$HOME/.pi/agent/sandbox.ts" "$@"' -- $pi_args
