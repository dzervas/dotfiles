#!/usr/bin/env bash
set -euo pipefail

TMP_SERV_PORT=35001

echo "Running pre-init openvpn command to get the SAML URL"

# Remove auth-federate, auth-retry and auth-user-pass from the AWS ovpn
VPN_OUT="$(openvpn-aws \
	--verb 1 \
	--config ~/Downloads/downloaded-client-config.ovpn \
	--auth-user-pass <(echo -e "N/A\nACS::$TMP_SERV_PORT") | \
	grep -Eo 'AUTH_FAILED,CRV1:.+')"

VPN_URL="$(echo -n "$VPN_OUT" | grep -Eo 'https://.+')"
echo "Opening the URL to the browser: $VPN_URL"
xdg-open "$VPN_URL"
VPN_SID="$(echo -n "$VPN_OUT" | cut -d: -f3)"

# Get the HTTP POST and keep only the last line (POST data)
SAML_RESPONSE_FULL="$(nc -l -W 1 -w 10 127.0.0.1 $TMP_SERV_PORT || { echo 'SAML response timeout'; exit 1; } | tail -n1)"
# Filter the SAMLResponse field
SAML_RESPONSE_ONLY="$(echo -n "$SAML_RESPONSE_FULL" | cut -d= -f2 | cut -d\& -f1)"
# URL decode the response
SAML_RESPONSE="$(printf "%b" "${SAML_RESPONSE_ONLY/\%/\\x}")"

echo "Got the SAML response, spawning the real OpenVPN"

sudo openvpn-aws \
	--config ~/Downloads/downloaded-client-config.ovpn \
	--auth-user-pass <(echo -e "N/A\nCRV1::$VPN_SID::$SAML_RESPONSE")
