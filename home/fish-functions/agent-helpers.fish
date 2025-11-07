#!/usr/bin/env fish

set -g __AGENT_UTILS_TOOLS

function mktool --description 'Generate a single JSON tool definition for LLM function calling'
	set -l name $argv[1]
	set -l description $argv[2]
	set -l callback $argv[3]

	if test -z "$argv[1]" -o -z "$argv[2]" -o -z "$argv[3]"
		echo (set_color red)"Error: Missing required arguments"(set_color normal) >&2
		return 1
	end

	set -l result (jq -c -r -n \
		--arg name "$name" \
		--arg description "$description" \
		'{"type": "function", name: $name, description: $description, parameters: { "type": "object", "properties": [], "required": []}}')

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
			'.parameters.properties += [{name: $name, type: $type, description: $desc}]')
	end

	set -a __AGENT_UTILS_TOOLS $result
end

# TODO: Support structured output
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
		--argjson temperature "$_flag_temperature" \
		--argjson max_tokens "$_flag_max_tokens" \
		--argjson tools "$__AGENT_UTILS_TOOLS" \
		'{model: $model, messages: [], temperature: $temperature, max_tokens: $max_tokens, tools: $tools}')

	if test -n "$_flag_system"
		set payload (echo $payload | jq -c -r --arg system "$_flag_system" '.messages += [{role: "system", content: $system}]')
	end

	set payload (echo $payload | jq -c -r --arg prompt "$argv" '.messages += [{role: "user", content: $prompt}]')

	curl -s --json "$payload" $__AGENT_UTILS_URL/v1/chat/completions
end

function llmrecv --description 'Parse an LLM response'
	read --null -l response
	set -l message (echo $response | jq -c -r '.choices[0].message')
	echo $message | jq -r '.content' >&2
end

# TODO: Do the tool calls
