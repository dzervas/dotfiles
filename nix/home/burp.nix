{ pkgs, ... }:
let
  burpsuite-pro = pkgs.burpsuite.override { proEdition = true; };
in
{
  home.packages = [ burpsuite-pro ];
}
