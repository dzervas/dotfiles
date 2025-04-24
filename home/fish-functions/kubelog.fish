if test (count $argv) -lt 1
	echo "Usage: $argv[0] RESOURCE_NAME [NAMESPACE]"
	return 1
end

set -f search_name $argv[1]
set -f namespace (kubectl config get-contexts (kubectl config current-context) --no-headers | awk '{ print $5 }')
if test (count $argv) -gt 1
	set namespace $argv[2]
end

alias k="kubectl -n $namespace"

set -f resource_order "services" "deployments" "statefulsets" ""

for resource in $resource_order
	set -f resource_subname (test $resource = "" && echo "pod/$search_name" || echo "$resource/$search_name")
	set -f name (kubectl get $resource_subname -o jsonpath="{.metadata.name}" || echo "")

	if test $name != $search_name
		continue
	end

	echo "✅ Found $resource_subname"

	set -f selector "app.kubernetes.io/name=$search_name"
	if test $resource = "services"
		set selector (kubectl get $resource_subname -o json | jq -r '.spec.selector | to_entries | map(.key + "=" + .value) | join(",")')
	else if test $resource = "deployments" -o $resource = "statefulsets"
		set selector (kubectl get $resource_subname -o json | jq -r '.spec.selector.matchLabels | to_entries | map(.key + "=" + .value) | join(",")')
	end

	set -f pods (kubectl get pod --selector "$selector" -o json | jq -r '[ .items.[] | .metadata.name ] | map("pod/" + .) | join(" ")')

	echo "⏳ Waiting for pod(s) to initialize"
	kubectl wait --for=condition=initialized --selector "$selector" pod

	kubectl logs --follow $resource_subname

	break
end
