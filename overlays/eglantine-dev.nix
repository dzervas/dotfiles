# Lichii's nvn-direct branch (NVN2 direct renderer, dotfiles-25x): eglantine.nix's recipe and sandbox.
# The branch's commits are local only, so the source is the lab checkout (git-ignored .pi, outside the flake).
# Update to the branch head:
#   git -C ~/Lab/dotfiles/.pi/lichii log -1 --format='%H %cs' nvn-direct-ux  # (the branch named in ref)
# then set rev and the version date below. Uncommitted worktree changes are never built.
{ callPackage }:
callPackage ./eglantine.nix {
  version = "0-unstable-2026-11-16";
  eglantineSrc = builtins.fetchGit {
    url = "file:///home/dzervas/Lab/dotfiles/.pi/lichii";
    ref = "nvn-direct-ux";
    rev = "2f67b9350cc4aebf9b12611313802b03b42b8076";
  };
}
