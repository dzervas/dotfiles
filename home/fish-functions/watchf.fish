# Default interval
set -l interval 2
set -l diff_highlight 0
set -l exit_on_diff 0
set -l exit_on_error 0

# Parse options using argparse
argparse --stop-nonopt 'n=' 'd' 'g' 'e' -- $argv
or return 1

# Handle options
if set -q _flag_n
	set interval $_flag_n
end
if set -q _flag_d
	set diff_highlight 1
end
if set -q _flag_g
	set exit_on_diff 1
end
if set -q _flag_e
	set exit_on_error 1
end

# The remaining arguments form the command to execute
set cmd $argv

if test (count $cmd) -eq 0
	echo "Usage: watch [options] command"
	return 1
end

# Initialize previous output
set -l prev_output

# Flag to signal loop to exit on Ctrl+C
set -g __watchf_active 1

while true
	# Capture output and status (faketty provides PTY for color output)
	# Python filter removes OSC sequences (terminal palette setup) but keeps color codes
	set -l output "$(faketty fish --private --interactive --command "$cmd" 2>&1 | python3 -c '
import sys, re
data = sys.stdin.read()
result = re.sub(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\x5c)", "", data)
sys.stdout.write(result.replace("\r", ""))
')"
	set -l retval $pipestatus[1]

	# Calculate the number of lines in the output
	set -l line_count (echo "$output" | wc -l)
	set -l buffer ""

	if test -n "$prev_output"
		# Move cursor up by prev_line_count lines
		set buffer "$buffer"(tput cuu $prev_line_count)

		# Move cursor to beginning of line
		set buffer "$buffer"(printf "\r")

		# Clear from cursor to end of screen
		# set buffer "$buffer"(tput ed)
	end

	if test $diff_highlight -eq 1 -a (set -q prev_output)
		# Compare outputs and highlight differences
		if test "$output" != "$prev_output"
			set -l tmp1 (mktemp)
			set -l tmp2 (mktemp)

			# Write outputs to temporary files
			echo "$prev_output" > $tmp1
			echo "$output" > $tmp2

			set output (difft --color=always $tmp1 $tmp2)

			rm $tmp1 $tmp2
		end
	end

	set -l el (tput el)
	set -l cols (tput cols)

	tput civis # Hide the cursor
	printf '%s' "$buffer"
	for line in $output
		printf "%s$el\n" (string shorten -m $cols $line)
	end
	tput cnorm # Show the cursor

	if test $exit_on_error -eq 1 -a $retval -ne 0
		break
	end

	if test $exit_on_diff -eq 1 -a "$output" != "$prev_output"
		break
	end

	# Update previous output and line count
	set prev_output "$output"
	# set prev_line_count (math $line_count + 1) # Account for the date line
	set prev_line_count "$line_count"

	set_color --bold cyan
	echo -n (date) >&2
	set_color normal
	tput ed # Clear the rest of the screen - in case the output got smaller

	sleep $interval
	or break # Exit loop if sleep is interrupted (Ctrl+C)
end

# Cleanup
tput cnorm 2>/dev/null
tput ed 2>/dev/null
echo
set -e __watchf_active
commandline -f repaint
