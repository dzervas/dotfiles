#!/usr/bin/env fish

# Find TODO and XXX comments, sort and group by filename
function find_comments
	rg --no-heading --color=never \
		-e '^\s*[#/*]* (XXX|TODO): ' \
		--type-add 'source:*.{c,cpp,h,hpp,nix,py,js,ts,java,go,rs,rb,php,sh,bash,fish}' \
		--type source \
		. 2>/dev/null | \
		sort -t: -k1,1 -k2,2
end

# Format and display results
function display_table
	set current_file ""
	set has_content false

	find_comments | while read -d: file comment_line
		set has_content true

		# Extract comment type and text
		set comment_type (echo "$comment_line" | rg -o ' (XXX|TODO):' | rg -o '(XXX|TODO)' | head -1)
		set comment_text (echo "$comment_line" | sed -E 's/^\s*[#/*]* (XXX|TODO):\s*//')

		# New file section
		if test "$file" != "$current_file"
			set current_file "$file"
			set_color blue
			echo "$current_file"
			set_color normal
		end

		# Format comment entry
		echo -n "    "
		if test "$comment_type" = "TODO"
			echo -en " "
			set_color yellow
		else if test "$comment_type" = "XXX"
			echo -en " "
			set_color magenta
		else
			echo -en " "
		end

		echo " $comment_text"
		set_color normal
	end

	if test "$has_content" = "false"
		echo "No action items found!"
	end
end

# Main execution
function main
	if not command -v rg >/dev/null 2>&1
		echo "❌ Error: ripgrep (rg) is not installed"
		echo "Install with: brew install ripgrep (macOS) or apt install ripgrep (Ubuntu)"
		exit 1
	end

	display_table
end

main $argv
