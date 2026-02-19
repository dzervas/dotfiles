# nix-update:webctl
{ lib
, python3
, fetchFromGitHub
, chromium
}:
python3.pkgs.buildPythonApplication rec {
  pname = "webctl";
  version = "0.3.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "cosinusalpha";
    repo = "webctl";
    rev = "v${version}";
    hash = "sha256-XNMn09lDNAxAvfj+SHWJ77osqsKZgMgRDFPpDlhyiJU=";
  };

  build-system = with python3.pkgs; [ hatchling ];

  postPatch = ''
    # Nix wraps Python entrypoints; subprocess calls via sys.executable lose wrapped deps.
    substituteInPlace src/webctl/config.py \
      --replace-fail '[sys.executable, "-m", "webctl.daemon.server", "--session", session_id]' \
                     '["webctld", "--session", session_id]'

    substituteInPlace src/webctl/cli/app.py \
      --replace-fail '[sys.executable, "-m", "playwright", "install", "chromium"]' \
                     '["playwright", "install", "chromium"]' \
      --replace-fail '[sys.executable, "-m", "playwright", "install-deps", "chromium"]' \
                     '["playwright", "install-deps", "chromium"]'
  '';

  dependencies = with python3.pkgs; [
    aiofiles
    lark
    markdownify
    playwright
    pydantic
    rich
    typer
  ];

  makeWrapperArgs = [
    "--set-default"
    "WEBCTL_BROWSER_PATH"
    "${chromium}/bin/chromium"
  ];

  pythonImportsCheck = [ "webctl" ];

  # Upstream test suite includes browser integration.
  doCheck = false;

  meta = with lib; {
    description = "Browser automation via CLI for humans and agents";
    homepage = "https://github.com/cosinusalpha/webctl";
    license = licenses.mit;
    mainProgram = "webctl";
    platforms = platforms.unix;
    maintainers = [];
  };
}
