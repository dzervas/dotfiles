#!/usr/bin/env python3

import lmstudio as lms

from os import getenv
from sys import argv, stderr
from typing import Optional

DEBUG = True if getenv("QQ_DEBUG") else False
MODEL = "qwen2.5-coder-1.5b-instruct"
SYSTEM_PROMPT = """
You are a concise NixOS terminal assistant. Your only purpose is to provide 1-2 direct commands to solve the user's technical query. Do not explain. Do not be chatty.

You must respond using this structured format:
{"cmd": ["command1", "command2"], "error": null}

If the question is off-topic, you MUST use this EXACT format:
{"cmd": null, "error": "I can only help with terminal tasks. Here is some trivia: [Your witty trivia here]"}

Follow the format of these examples perfectly.

USER: how to find a file named config.txt
ASSISTANT: {"cmd": ["find / -name \"config.txt\""], "error": null}

USER: what is the meaning of life
ASSISTANT: {"cmd": null, "error": "I can only help with terminal tasks. Here is some trivia: The first computer bug was an actual bug! A moth trapped in a Harvard Mark II computer in 1947."}

USER: list all listening ports
ASSISTANT: {"cmd": ["ss -tuln", "netstat -tuln"], "error": null}

USER: convert an mp4 to mp3
ASSISTANT: {"cmd": ["ffmpeg -i input.mp4 output.mp3"], "error": null}
"""

class QQResponse(lms.BaseModel):
	cmd: Optional[str]
	error: Optional[str] # Could be a list

def main():
	api_host = lms.Client.find_default_local_api_host()
	client = lms.Client(api_host)
	model = client.llm.model(MODEL)

	chat = lms.Chat(SYSTEM_PROMPT)
	chat.add_user_message(argv[1:])

	response = model.respond(chat, response_format=QQResponse, config={
		"temperature": 0.1,
		"max_tokens": 1024,
	})

	if DEBUG:
		print(response)

	if response.parsed["error"] or not response.parsed["cmd"]:
		print(response.parsed["error"], file=stderr)
		return 1

	print(response.parsed["cmd"])

if __name__ == "__main__":
	main()
