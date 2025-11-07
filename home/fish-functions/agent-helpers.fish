#!/usr/bin/env fish

set -ge __AGENT_UTILS_TOOLS

# Usage: mktool <name> <description> <callback> [<param>:<type>:<description>[:r (required)]]...
function mktool --description 'Generate a single JSON tool definition for LLM function calling'
	set -l name $argv[1]
	set -l description $argv[2]
	set -l callback $argv[3]

	if test -z "$name" -o -z "$description" -o -z "$callback"
		echo (set_color red)"Error: Missing required arguments"(set_color normal) >&2
		return 1
	end

	set -l result (jq -c -r -n \
		--arg name "$name" \
		--arg description "$description" \
		'{type: "function", name: $name, description: $description, parameters: { "type": "object", "properties": {}, "required": []}}')

	for param in $argv[4..]
		# Split the parameter string into parts (max 3 splits)
		set parts (string split -m 2 ':' $param)

		# Check for valid parameter format
		if test (count $parts) -lt 3
			echo (set_color yellow)"Warning: Skipping malformed parameter '$param'"(set_color normal) >&2
			continue
		end

		set -l name $parts[1]
		set -l type $parts[2]
		set -l desc $parts[3]
		set -l is_required false

		# Check if the last part of the description ends with ':r'
		if string match -q "*:r" $desc
			set desc (string sub -e -2 "$desc") # Remove the ':r' suffix
			set result (echo $result | jq -c -r --arg name "$name" '.parameters.required += [$name]')
		end

		# Add to the properties list for the JSON object
		set result (echo $result | jq -c -r \
			--arg name "$name" \
			--arg type "$type" \
			--arg desc "$desc" \
			'.parameters.properties[$name] = {type: $type, description: $desc}')
	end

	if test -z "$__AGENT_UTILS_TOOLS" -o "$__AGENT_UTILS_TOOLS" = "null"
		set -g __AGENT_UTILS_TOOLS "[$result]"
	else
		set -g __AGENT_UTILS_TOOLS (echo "$__AGENT_UTILS_TOOLS" | jq -c -r --argjson tool "$result" '. += $tool')
	end
end

# TODO: Support structured output
# Usage: llmsend [-m <model>] [-s <system>] [-t <temperature>] [-max-tokens <max-tokens>] <prompt>
function llmsend --description 'Send a message to the LLM agent'
	argparse "m/model=" "s/system=" "t/temperature=" "max-tokens=" -- $argv

	if test -z "$argv"
		echo (set_color red)"llmsend: missing prompt argument"(set_color normal) >&2
		return 1
	end

	if test -z "$__AGENT_UTILS_TOOLS"
		set __AGENT_UTILS_TOOLS "null"
	end
	if test -z "$_flag_temperature"
		set _flag_temperature "null"
	end
	if test -z "$_flag_max_tokens"
		set _flag_max_tokens "null"
	end

	set -l payload (jq -c -r -n \
		--arg model "$_flag_model" \
		--arg prompt "$argv" \
		--argjson temperature "$_flag_temperature" \
		--argjson max_tokens "$_flag_max_tokens" \
		--argjson tools "$__AGENT_UTILS_TOOLS" \
		'{model: $model, input: $prompt, temperature: $temperature, max_tokens: $max_tokens, tools: $tools}')

	if test -n "$_flag_system"
		set payload (echo $payload | jq -c -r --arg system "$_flag_system" '.instructions = $system')
	end

	test -n "$__AGENT_UTILS_DEBUG" && echo $payload | jq . >&2
	set payload (echo "$payload" | jq -c -r 'del(..|nulls)')

	curl -s --json "$payload" $__AGENT_UTILS_URL/v1/responses
end

# Usage: echo <response> | llmrecv
function llmrecv --description 'Parse an LLM response'
	read --null -l response

	test -n "$__AGENT_UTILS_DEBUG" && echo $response | jq . >&2

	set -l error (echo $response | jq -r '.error.message')

	# Check for an error
	if test "$error" != "null"
		echo (set_color red)"Error: $error"(set_color normal) >&2
		return 1
	end

	set -l output_count (echo $response | jq '.output | length')

	# Iterate over all output items
	for i in (seq 0 (math $output_count - 1))
		set -l item (echo $response | jq -c -r ".output[$i]")
		set -l type (echo $item | jq -r '.type')

		switch $type
			case "message"
				set -l content (echo $item | jq -r '.content[] | .text')
				echo (set_color --bold)$content(set_color normal)

			case "function_call"
				# TODO: Handle tool calls
				set -l tool_name (echo $item | jq -r '.name')
				set -l tool_args (echo $item | jq -r '.arguments')
				echo (set_color yellow)"Warning: Tool call handling not implemented yet - $tool_name($tool_args)"(set_color normal) >&2

			case '*'
				echo (set_color --bold yellow)"Warning: Unknown response type '$type'"(set_color normal) >&2
				echo
				echo (set_color --dim)"Full item: $item"(set_color normal) >&2
		end
	end
end

# TODO: Do the tool calls
