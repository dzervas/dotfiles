function kubeseal-env
	if test (count $argv) -lt 1 -o (count $argv) -gt 2 -o "$argv[1]" = "-h" -o "$argv[1]" = "--help"
		echo "Usage: kubeseal-env <env file> [namespace]"
		return 1
	end

	set -f env_file $argv[1]
	set -f namespace $argv[2]

	if test -z $argv[2]
		set -f namespace (kubens -c)
	end

	echo "Env file $env_file will be sealed for $namespace/$(kubectx -c). You sure?" >&2
	read

	kubectl create secret -n "$namespace" generic -o yaml --from-env-file "$env_file" --dry-run=client (basename $env_file) | kubeseal -o yaml
end
