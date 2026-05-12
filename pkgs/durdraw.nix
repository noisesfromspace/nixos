{
  lib,
  python3,
  fetchFromGitHub,
}:

python3.pkgs.buildPythonApplication (finalAttrs: {
  pname = "durdraw";
  version = "0.29.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "cmang";
    repo = "durdraw";
    tag = finalAttrs.version;
    hash = "sha256-a+4DGWBD5XLaNAfTN/fmI/gALe76SCoWrnjyglNhVPY=";
  };

  build-system = [
    python3.pkgs.setuptools
    python3.pkgs.wheel
  ];

  optional-dependencies = with python3.pkgs; {
    gif-export = [
      pillow
    ];
  };

  pythonImportsCheck = [
    "durdraw"
  ];

  meta = {
    description = "Versatile ASCII and ANSI Art text editor for drawing in the Linux/Unix/macOS terminal, with animation, 256 and 16 colors, Unicode and CP437, and customizable themes";
    homepage = "https://github.com/cmang/durdraw";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "durdraw";
  };
})
