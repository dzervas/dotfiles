#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.12"
# dependencies = ["lmstudio"]
# ///

import lmstudio as lms

def top() -> [str]:
    """Gives a list of all the processes running on the system and their CPU & memory usage"""

    import subprocess

    ps = subprocess.run(["top", "-b", "-n", "1"], capture_output=True, text=True)
    return ps.stdout.split("\n")

model = lms.llm("ibm/granite-4-h-tiny")
model.act(
  "Give me the top 5 processes on the system based on ram usage",
  [top],
  on_message=print,
)
