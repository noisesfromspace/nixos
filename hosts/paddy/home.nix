{ pkgs, ... }:
{
  imports = [
    ../../home
  ];

  home.packages = [ pkgs.cloudfoundry-cli ];
  programs.niri.settings.input.keyboard.xkb.options = "caps:escape";
  maatwerk.sync.work.enable = true;
  maatwerk.niri = {
    enable = true;
    isLaptop = true;
    laptopScalingFactor = 1.33;
  };
}
