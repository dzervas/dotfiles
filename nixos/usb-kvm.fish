#!/usr/bin/env fish

# Input Source VCP feature ID
set -l INPUT_VCP "0x60"
set -l VALUES_VCP_DP "0x0f" # Value for DisplayPort-1
set -l VALUES_VCP_HDMI "0x11" # Value for HDMI-1

set -l device_count (ddcutil detect --brief | rg '^Display \d$' | wc -l)
echo "Found $device_count monitors"

set -l skip 0
set -l displays
set -l connectors
set -l serials

for line in (ddcutil detect)
	# Skip empty lines
	if string match -qr '^$' $line
		continue
	end

	# Detect "root" lines and skip them
	if not string match -qr '^\s' $line
		# Detect "Display" lines
		if string match -qr "Display \d" $line
			set -a displays (echo $line | cut -d' ' -f2)
			set skip 0
		else
			set skip 1
		end

		continue
	end

	# If the whole block is skipped, skip the current line
	if test $skip -eq 1
		echo "Skipping line: $line"
		continue
	end

	# Parse the key-value pairs
	set -l key (echo $line | cut -d: -f1 | string trim)
	set -l value (echo $line | cut -d: -f2 | string trim)

	# Extract the values that we need
	if string match -q "DRM connector" $key
		set -a connectors $value
	else if string match -q "Serial number" $key
		set -a serials $value
	end
end

function setvcp-if-not-set
	set -f display $argv[1]
	set -f vcp $argv[2]
	set -f value $argv[3]

	set -f current_value (ddcutil getvcp --brief --display $display $vcp | cut -d' ' -f4)

	# For some reason ddcuitl returns "x11" instead of "0x11"
	if test "0$current_value" -ne $value
		echo "Setting $vcp to $value for monitor $display"
		ddcutil setvcp --display $display $vcp $value
	else
		echo "VCP $vcp is already set to $value for monitor $display"
	end
end

for d in $displays
	set -l connector $connectors[$d]
	set -l serial $serials[$d]

	if string match -q "*-DP-*" $connector
		echo "Setting DisplayPort for monitor $d"
		setvcp-if-not-set $d $INPUT_VCP $VALUES_VCP_DP
	else if string match -q "*-HDMI-*" $connector
		echo "Setting HDMI for monitor $d"
		setvcp-if-not-set $d $INPUT_VCP $VALUES_VCP_HDMI
	else
		echo "Unknown connector type: $connector"
	end
end
