#!/usr/bin/env bash
set -euo pipefail

context=$1
bootstrap_context=$2
serviceaccount=$3
namespace=$4

description="kube-token:${context}:${namespace}:${serviceaccount}"

# Decode the expiry claim from a Kubernetes ServiceAccount JWT.
jwt_expiry() {
	local payload
	payload="${1#*.}"
	payload="${payload%%.*}"
	payload="${payload//-/+}"
	payload="${payload//_//}"

	while ((${#payload} % 4)); do
		payload+="="
	done

	printf '%s' "$payload" | base64 -d | jq -er '.exp | numbers'
}

# Return an ExecCredential without placing the token in argv.
emit_credential() {
	local token="$1"
	local exp="$2"
	local timestamp

	timestamp=$(date -u -d "@$exp" '+%Y-%m-%dT%H:%M:%SZ')

	echo -n "$token" | jq -Rs --arg expiry "$timestamp" '{
		apiVersion: "client.authentication.k8s.io/v1",
		kind: "ExecCredential",
		status: {
			token: .,
			expirationTimestamp: $expiry
		}
	}'
}

now=$(date +%s)

# Try the keyring cache.
if id=$(keyctl search @s user "$description" 2>/dev/null); then
	if token=$(keyctl pipe "$id" 2>/dev/null); then
		if exp=$(jwt_expiry "$token" 2>/dev/null); then
			if ((exp > now + 150)); then
				emit_credential "$token" "$exp"
				exit 0
			fi
		fi
	fi

	keyctl revoke "$id" >&2 || true
fi

# Cache miss: authenticate through the original X.509
# exec plugin, then request a short-lived SA token.
echo "Cache miss, minting SA token..." >&2
token=$(
	kubectl --context="$bootstrap_context" \
		-n "$namespace" \
		create token "$serviceaccount" \
		--duration=10m
)

exp=$(jwt_expiry "$token")
now=$(date +%s)
ttl=$((exp - now - 30))

if ((ttl <= 0)); then
	echo "Issued token has insufficient lifetime" >&2
	exit 1
fi

# Create an empty key before inserting secret material.
id=$(printf '\0' | keyctl padd user "$description" @s)

if ! keyctl setperm "$id" 0x3f000000; then
	keyctl revoke "$id" >&2 || true
	echo "Failed to restrict token key permissions" >&2
	exit 1
fi

# Insert the token and apply a kernel-enforced TTL.
if ! echo -n "$token" | keyctl pupdate "$id"; then
	keyctl revoke "$id" >&2 || true
	exit 1
fi

if ! keyctl timeout "$id" "$ttl"; then
	keyctl revoke "$id" >&2 || true
	exit 1
fi

emit_credential "$token" "$exp"
