#!/usr/bin/env fish

set API_TOKEN "$(op read 'op://Private/AnyType Local Key/api')"
set SPACEID (anytype-cli space list | rg Life | awk '{ print $1 }')
echo "Space ID: $SPACEID" >&2

function acurl
	set -l URL "http://127.0.0.1:31012/v1/spaces/$SPACEID/$argv[1]"

	curl -L "$URL" \
		-H "Accept: application/json" \
		-H "Authorization: Bearer $API_TOKEN" \
		$argv[2..-1]
end

acurl "objects?limit=1000&type=task" | jq -r '.data[] | .tags = (.properties[] | select(.key == "tag").multi_select | map(.key))'
