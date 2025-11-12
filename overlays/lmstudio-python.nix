# nix-update:lmstudio-python
{ lib
, python3
, fetchPypi
}: python3.pkgs.buildPythonPackage rec {
  pname = "lmstudio-python";
  version = "1.5.0";

  format = "pyproject";
  build-system = with python3.pkgs; [ pdm-backend ];

  src = fetchPypi {
    inherit version;
    pname = "lmstudio";
    hash = "sha256-RYw0/h+Up9zFIdQia0zugrivfqPajECzG72sVY2adNQ=";
  };

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
    maintainers = [];
  };
}
