#!/usr/bin/env python3

import lmstudio as lms

from os import getenv
from sys import argv, stderr
from typing import Optional

DEBUG = True if getenv("SA_DEBUG") else False
# MODEL = "openai/gpt-oss-20b"
MODEL = "qwen2.5-coder-3b-instruct"
SYSTEM_PROMPT = """
You are a NixOS system debugger. Your purpose is to diagnose and resolve system issues using available tools. Be precise and efficient in your debugging approach.
Do not assume and do not guess, use the tools provided to find the root	cause of the problem.

If needed, ask follow-up questions to clarify the problem.
"""


class bcolors:
	RED = '\033[31m'
	CYAN = '\033[36m'
	BYELLOW = '\033[93m'
	BRED = '\033[91m'

	ENDC = '\033[0m'
	BOLD = '\033[1m'
	DIM = '\033[2m'
	UNDERLINE = '\033[4m'


def top() -> list[str]:
	"""Gives a list of the 10 top processes running on the system with: PID, USER, PR, NI, VIRT, RES, SHR, S, %CPU, %MEM, TIME+, COMMAND"""
	import subprocess
	ps = subprocess.run(["top", "-b", "-n", "1"], capture_output=True, text=True)
	return ps.stdout.split("\n")[:10]

def ping1() -> list[str]:
	"""Ping 1.1.1.1 4 times with a 1 second timeout and return the output"""
	import subprocess
	ps = subprocess.run(["ping", "-c", "1", "-W", "1", "1.1.1.1"], capture_output=True, text=True)
	return ps.stdout.split("\n")

def on_message(message: lms.AnyChatMessage):
	for content in message.content:
		if content.type == "text":
			if not content.text.strip():
				continue

			print(content.text, end="")
		elif content.type == "toolCallRequest":
			request = content.tool_call_request
			request_str = f"{request.name}({','.join(request.arguments)})"
			print(f"{bcolors.RED}󱢇 {bcolors.ENDC} {bcolors.DIM}{request_str}{bcolors.ENDC}", end="")
		elif content.type == "toolCallResult":
			result = "".join(content.content)
			print(f"{bcolors.CYAN}󰌑 {bcolors.ENDC} {bcolors.DIM}{result}{bcolors.ENDC}", end="")

		print()

def main():
	api_host = lms.Client.find_default_local_api_host()
	client = lms.Client(api_host)
	model = client.llm.model(MODEL)

	chat = lms.Chat(SYSTEM_PROMPT)
	chat.add_user_message(argv[1:])

	def on_message_chat(msg):
		chat.append(msg)
		on_message(msg)

	tools = [
		top,
		ping1,
	]
	response = model.act(chat, tools, on_message=on_message_chat, config={
		"temperature": 0.3,
		"max_tokens": 1024,
	})

	# if DEBUG:
	# 	print(response)
	# print(response.content)

if __name__ == "__main__":
	main()
