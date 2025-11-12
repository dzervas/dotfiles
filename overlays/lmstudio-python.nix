# nix-update:lmstudio-python
{ lib
, python3
, fetchFromGitHub
}: python3.pkgs.buildPythonPackage rec {
  pname = "lmstudio";
  version = "1.6.0b1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "lmstudio-ai";
    repo = "lmstudio-python";
    rev = version;
    hash = "sha256-QJNVlkSmwinoJ/cMCDpYzYDmd6Q8AGiLHHdk36Fqtk8=";
  };

  build-system = with python3.pkgs; [
    pdm-backend
  ];

  dependencies = with python3.pkgs; [
    httpx
    httpx-ws
    msgspec
    typing-extensions
    anyio
  ];

  pythonImportsCheck = [ "lmstudio" ];

  meta = with lib; {
    description = "LM Studio Python SDK";
    homepage = "https://github.com/lmstudio-ai/lmstudio-python";
    license = licenses.mit;
    maintainers = [ ];
  };
}
