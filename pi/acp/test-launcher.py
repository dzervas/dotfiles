"""Exercise the real launcher and sand parser without starting Pi or bubblewrap."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys

LAUNCHER = Path(__file__).with_name("run-pi.fish").resolve()


class SandboxLauncherTest(unittest.TestCase):
    def test_adapter_selects_executable_pi_launcher_without_changing_cwd(self):
        with tempfile.TemporaryDirectory(prefix="pi-acp-host-") as temporary:
            root = Path(temporary)
            adapter = root / "pi-acp"
            adapter.write_text(
                f"#!{sys.executable}\n"
                "import json, os, sys\n"
                "print(json.dumps({'launcher': os.environ['PI_ACP_PI_COMMAND'], "
                "'reader': os.environ['PI_ACP_READ_COMMAND'], "
                "'args': sys.argv[1:], 'cwd': os.getcwd()}))\n"
            )
            adapter.chmod(0o755)
            result = subprocess.run(
                ["fish", "--no-config", str(LAUNCHER.with_name("run-acp.fish")), "argument with spaces"],
                cwd=root,
                env={**os.environ, "PATH": str(root) + os.pathsep + os.environ["PATH"]},
                capture_output=True,
                check=True,
            )
            self.assertTrue(os.access(LAUNCHER, os.X_OK))
            self.assertTrue(os.access(LAUNCHER.with_name("read-file.fish"), os.X_OK))
            self.assertEqual(json.loads(result.stdout), {
                "launcher": str(LAUNCHER), "reader": str(LAUNCHER.with_name("read-file.fish")),
                "args": ["argument with spaces"], "cwd": str(root),
            })

    def test_each_session_mounts_its_own_project_and_preserves_rpc_arguments(self):
        with tempfile.TemporaryDirectory(prefix="pi-acp-launcher-") as temporary:
            root = Path(temporary)
            home = root / "home"
            home.mkdir()
            projects = [home / "project one", home / "project two"]
            for project in projects:
                project.mkdir()
                args = ["--mode", "rpc", "--session", str(home / "a session.jsonl"), "", "*"]
                script = '''
function direnv
    # The real command outputs Fish statements for the current project's env.
    printf 'set -gx LAUNCHER_TEST_PROJECT "%s"\\n' "$PWD"
end
function bwrap
    printf '%s\\0' "$PI_ACP_FORMS" "$LAUNCHER_TEST_PROJECT" $argv
end
source $argv
'''
                result = subprocess.run(
                    ["fish", "--no-config", "-c", script, "--", str(LAUNCHER), *args],
                    cwd=project,
                    env={**os.environ, "HOME": str(home)},
                    capture_output=True,
                    check=True,
                )
                values = result.stdout.decode().split("\0")[:-1]
                self.assertEqual(values[:2], ["1", str(project)])
                bwrap_args = values[2:]
                self.assertEqual(bwrap_args[bwrap_args.index("--chdir") + 1], str(project))
                project_binding = ["--bind", str(project), str(project)]
                self.assertTrue(any(bwrap_args[i:i + 3] == project_binding for i in range(len(bwrap_args))))
                command_index = bwrap_args.index("--")
                command = bwrap_args[command_index + 1:]
                self.assertEqual(command[:2], ["bash", "-lc"])
                self.assertEqual(command[2], 'exec pi --extension "$HOME/.pi/agent/sandbox.ts" "$@"')
                self.assertEqual(command[3:], ["--", *args])

    def test_diff_reader_uses_the_same_project_sandbox(self):
        with tempfile.TemporaryDirectory(prefix="pi-acp-reader-") as temporary:
            root = Path(temporary)
            home = root / "home"
            project = home / "project with spaces"
            project.mkdir(parents=True)
            path = str(project / "a file.txt")
            result = subprocess.run(
                ["fish", "--no-config", "-c", '''
function bwrap
    printf '%s\\0' $argv
end
source $argv
''', "--", str(LAUNCHER.with_name("read-file.fish")), path],
                cwd=project,
                env={**os.environ, "HOME": str(home)},
                capture_output=True,
                check=True,
            )
            args = result.stdout.decode().split("\0")[:-1]
            self.assertEqual(args[args.index("--chdir") + 1], str(project))
            command = args[args.index("--") + 1:]
            self.assertEqual(command[:2], ["bash", "-c"])
            self.assertEqual(command[2], 'exec node /tmp/pi-acp-read-file.mjs "$@"')
            self.assertEqual(command[3:], ["--", path])
            self.assertTrue(any(args[i:i + 3] == [
                "--ro-bind", str(LAUNCHER.with_name("read-file.mjs")), "/tmp/pi-acp-read-file.mjs",
            ] for i in range(len(args))))

    def test_diff_reader_returns_exact_bytes_or_missing_status(self):
        with tempfile.TemporaryDirectory(prefix="pi-acp-reader-bytes-") as temporary:
            home = Path(temporary) / "home"
            project = home / "project"
            project.mkdir(parents=True)
            path = project / "file with spaces.txt"
            reader = LAUNCHER.with_name("read-file.fish")
            script = '''
function bwrap
    set -l reader
    for i in (seq (count $argv))
        if test "$argv[$i]" = /tmp/pi-acp-read-file.mjs
            set -l previous (math $i - 1)
            set reader $argv[$previous]
        end
    end
    set -l index (contains -i -- -- $argv)
    set index (math $index + 1)
    set -l command $argv[$index..-1]
    set command[3] (string replace /tmp/pi-acp-read-file.mjs "$reader" -- "$command[3]")
    command $command
end
source $argv
'''
            for content in ["héllo\\n\\n".encode(), b"", None]:
                if content is None:
                    path.unlink()
                else:
                    path.write_bytes(content)
                result = subprocess.run(
                    ["fish", "--no-config", "-c", script, "--", str(reader), str(path)],
                    cwd=project,
                    env={**os.environ, "HOME": str(home)},
                    capture_output=True,
                )
                self.assertEqual(result.returncode, 44 if content is None else 0, result.stderr.decode())
                self.assertEqual(result.stdout, b"" if content is None else content)

    def test_opened_snapshot_descriptor_must_be_inside_project(self):
        with tempfile.TemporaryDirectory(prefix="pi-acp-reader-guard-") as temporary:
            root = Path(temporary)
            project = root / "project"
            project.mkdir()
            outside = root / "outside.txt"
            outside.write_text("fixture outside project")
            (project / "escape").symlink_to(root, target_is_directory=True)
            for path in [outside, project / "escape" / "outside.txt"]:
                result = subprocess.run(
                    ["node", str(LAUNCHER.with_name("read-file.mjs")), str(path)],
                    cwd=project,
                    capture_output=True,
                )
                self.assertEqual(result.returncode, 1)
                self.assertEqual(result.stdout, b"")


if __name__ == "__main__":
    unittest.main()
