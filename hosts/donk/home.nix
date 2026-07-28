{ ... }:
{
  imports = [
    ../../home
  ];

  programs.niri.settings.input.keyboard.xkb.options = "caps:escape";

  home.packages = [ ];

  maatwerk.niri = {
    enable = true;
    isLaptop = true;
    laptopScalingFactor = 1.0;
  };

  maatwerk.pi.server.enable = true;
}
