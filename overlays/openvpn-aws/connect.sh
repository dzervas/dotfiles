#!/usr/bin/env bash
set -euo pipefail

OVPN_FILE=/home/dzervas/Downloads/downloaded-client-config.ovpn
TMP_SERV_PORT=35001

# create random hostname prefix for the vpn gw
# RAND="$(openssl rand -hex 12)"
# REMOTE="$(grep '^remote ' "$OVPN_FILE" | cut -d' ' -f2)"

# resolv manually hostname to IP, as we have to keep persistent ip address
# REMOTE_IP=$(dig a +short "${RAND}.${REMOTE}"|head -n1)

echo "Running pre-init openvpn command to get the SAML URL"

# Remove auth-federate, auth-retry and auth-user-pass from the AWS ovpn
VPN_OUT="$(openvpn-aws \
	--verb 1 \
	--config "$OVPN_FILE" \
	--auth-user-pass <(echo -e "N/A\nACS::$TMP_SERV_PORT") | \
	grep -E 'AUTH_FAILED,CRV1:.+')"

VPN_URL="$(echo -n "$VPN_OUT" | grep -Eo 'https://.+')"
echo "Opening the URL to the browser: $VPN_URL"
xdg-open "$VPN_URL"
# VPN_SID="$(echo -n "$VPN_OUT" | cut -d: -f3)"
VPN_SID="$(echo -n "$VPN_OUT" | awk -F: '{print $7}')"

# Get the HTTP POST and keep only the last line (POST data)
SAML_RESPONSE_FULL="$(nc -l -W 1 -w 10 127.0.0.1 $TMP_SERV_PORT || { echo 'SAML response timeout'; exit 1; } | tail -n1)"
# Filter the SAMLResponse field
SAML_RESPONSE_ONLY="$(echo -n "$SAML_RESPONSE_FULL" | tail -n1 | cut -d= -f2 | cut -d\& -f1 | tr -d "[:space:]")"
# URL decode the response
SAML_RESPONSE="$(printf "%b" "${SAML_RESPONSE_ONLY/\%/\\x}")"

echo "Got the SAML response, spawning the real OpenVPN"

sudo bash -c 'openvpn-aws \
	--config '"$OVPN_FILE"' \
	--auth-user-pass <(echo -e "N/A\nCRV1::'"$VPN_SID"'::'"$SAML_RESPONSE"'")'
