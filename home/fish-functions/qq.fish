#!/usr/bin/env fish

set -l SYSTEM_PROMPT '
You are a concise NixOS terminal assistant. Your only purpose is to provide 1-2 direct commands to solve the user\'s technical query. Do not explain. Do not be chatty.

If the question is off-topic, you MUST use this EXACT format:
<warn>I can only help with terminal tasks. Here is some trivia:</warn><br/><info>[Your witty trivia here]</info>

Follow the format of these examples perfectly.

USER: how to find a file named config.txt
ASSISTANT: <cmd>find / -name "config.txt"</cmd>

USER: what is the meaning of life
ASSISTANT: <warn>I can only help with terminal tasks. Here is some trivia:</warn><br/><info>The first computer bug was an actual bug! A moth trapped in a Harvard Mark II computer in 1947.</info>

USER: list all listening ports
ASSISTANT: <cmd>ss -tuln</cmd><br/><cmd>netstat -tuln</cmd>

USER: convert an mp4 to mp3
ASSISTANT: <cmd>ffmpeg -i input.mp4 output.mp3</cmd>
'

if test -z "$argv"
	echo "$(set_color red)qq: missing argument$(set_color normal)"
	return 1
end

set -l MODEL "qwen2.5-coder-1.5b-instruct"
if test -n "$QQ_MODEL"
	set MODEL "$QQ_MODEL"
end
set -l LMS_OUTPUT (lms chat -s "$SYSTEM_PROMPT" -p "$argv" "$MODEL")

# Colorize the output
# TODO: Use lmstudio structured output instead:
# https://lmstudio.ai/docs/developer/openai-compat/structured-output
echo -e $LMS_OUTPUT | sed \
	-e "s|<cmd>|$(set_color blue)|g" -e "s|</cmd>|$(set_color normal)|g" \
	-e "s|<warn>|$(set_color --bold bryellow)|g" -e "s|</warn>|$(set_color normal)|g" \
	-e "s|<info>|$(set_color --dim blue)|g" -e "s|</info>|$(set_color normal)|g" \
	-e "s|<bold>|$(set_color --bold white)|g" -e "s|</bold>|$(set_color normal)|g" \
	-e "s|<file>|$(set_color --dim green)|g" -e "s|</file>|$(set_color normal)|g" \
	-e "s|<br/>|\n|g"

read -l -n1 -P "Complete (enter)/Retry (r): " choice

# Prepare the output for the commandline
set -l CMD_LMS_OUTPUT (echo $LMS_OUTPUT | sed "s|<br/>|\n|g" | rg -o '<cmd>.*</cmd>' | sed -E -e "s|<cmd>||g" -e "s|</cmd>|\n|" | string trim -l -r -c "\n")

if test -z "$choice"
	commandline -r "$CMD_LMS_OUTPUT"
	commandline -f repaint
else if test "$choice" = 'r'
	qq $argv
end
