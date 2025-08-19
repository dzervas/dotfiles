#!/bin/sh
TAG=gha-updater
FILES=$(grep -rlnF "# $TAG:" | grep '\.nix$')

echo "Gathered tag $TAG in:"
echo "$FILES"
echo

for file in $FILES; do
	echo "Updating $file"
	COUNT=$(grep --count -F "# $TAG:" $file)

	for i in $(seq 1 $COUNT); do
		CMD=$(grep -Fm $i "# $TAG:" $file | tail -n1 | cut -d':' -f2-)

		LINES=$(grep -nF "# $TAG:$CMD" $file -A2 | tail -n2)
		URL_LINE=$(echo "$LINES" | head -n1)
		HASH_LINE=$(echo "$LINES" | tail -n1)

		URL_NO=$(echo "$URL_LINE" | cut -d'-' -f1)
		URL=$(echo "$URL_LINE" | cut -d'-' -f2- | grep -oE '(https?://[^ ";]+|v?[0-9]{1,3}\.[0-9]{1,3}(\.[0-9]+)?)')
		HASH_NO=$(echo "$HASH_LINE" | cut -d'-' -f1)
		HASH=$(echo "$HASH_LINE" | cut -d'-' -f2- | grep -oE '([a-z0-9]{52}|sha256-[a-zA-Z0-9/=]{44})')

		echo "URL: '$URL' ($URL_NO) HASH: '$HASH' ($HASH_NO)"
		echo "Running: $CMD"

		NEW_DATA=$(eval "$CMD")
		echo "New data: $NEW_DATA"
		NEW_URL=$(echo "$NEW_DATA" | cut -d' ' -f1)
		NEW_HASH=$(echo "$NEW_DATA" | cut -d' ' -f2)

		if $(echo "$NEW_URL" | grep -qE '^[0-9a-z]{52}$'); then
			if [ "$NEW_URL" = "$NEW_HASH" ] || [ "$NEW_HASH" = "" ]; then
				NEW_HASH=$NEW_URL
				NEW_URL=""
			else
				tmp=$NEW_HASH
				NEW_HASH=$NEW_URL
				NEW_URL=$tmp
			fi
		fi

		echo "New URL: $NEW_URL New HASH: $NEW_HASH"

		if [ "$NEW_URL" = "" ] && [ "$NEW_HASH" = "" ]; then
			echo "Failed to get new data"
			continue
		fi

		if [ "$NEW_URL" != "" ]; then
			sed -Ei "${URL_NO}s|$URL|$NEW_URL|g" "$file" || echo "Failed to update URL"
		fi

		if [ "$NEW_HASH" != "" ]; then
			sed -Ei "${HASH_NO}s|$HASH|$NEW_HASH|g" "$file" || echo "Failed to update HASH"
		fi

		echo
	done

	echo ---
	echo
done
