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

while true
	# Capture output and status
	set -l output "$(fish --private --interactive --command "$cmd" 2>&1)"
	set -l retval $status

	# Clear screen
	clear

	if test $diff_highlight -eq 1 -a (set -q prev_output)
		# Compare outputs and highlight differences
		if test "$output" != "$prev_output"
			set -l tmp1 (mktemp)
			set -l tmp2 (mktemp)

			# Write outputs to temporary files
			echo "$prev_output" > $tmp1
			echo "$output" > $tmp2

			difft --color=always $tmp1 $tmp2

			rm $tmp1 $tmp2
		else
			# If outputs are the same, display the output
			printf '%s\n' "$output"
		end
	else
		# Display the output
		printf '%s\n' "$output"
	end

	if test $exit_on_error -eq 1 -a $retval -ne 0
		return $retval
	end

	if test $exit_on_diff -eq 1 -a "$output" != "$prev_output"
		return 0
	end

	set prev_output "$output"

	sleep $interval
end
