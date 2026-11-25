# Lichii's nvn-direct branch (NVN2 direct renderer, dotfiles-25x): eglantine.nix's recipe and sandbox.
# The branch's commits are local only, so the source is the lab checkout (git-ignored .pi, outside the flake).
# Update to the branch head:
#   git -C ~/Lab/dotfiles/.pi/lichii log -1 --format='%H %cs' nvn-direct-ux  # (the branch named in ref)
# then set rev and the version date below. Uncommitted worktree changes are never built.
{
  callPackage,
  eden,
  ...
}: callPackage ./eglantine.nix {
  # This Lichii source already includes Eden's fix for newer Linux UAPI headers.
  eden = eden.overrideAttrs (_finalAttrs: oldAttrs: {
    patches = builtins.filter (
      patch: (patch.name or null) != "305f40100d76ec57b13c2f03eafd490db83691cb.patch"
    ) (oldAttrs.patches or []);
  });
  version = "0-unstable-2026-11-20";
  eglantineSrc = builtins.fetchGit {
    url = "file:///home/dzervas/Lab/lichii";
    ref = "main";
    rev = "727caa6d72eb48242942123894215a6b07bf1a33";
  };
}
