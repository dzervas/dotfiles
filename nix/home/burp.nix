{ pkgs, ... }:
let
  burpsuite-pro = pkgs.burpsuite.override { proEdition = true; };
in
{
  home.packages = with pkgs; [ burpsuite-pro ];
}
