{ ... }:
{
  imports = [
    ../../home
  ];

  programs.niri.settings.input.keyboard.xkb.options = "caps:escape";
  maatwerk.sync.work.enable = true;
  maatwerk.niri = {
    enable = true;
    isLaptop = true;
    laptopMonitorName = "eDP-1";
    laptopScalingFactor = 1.33;
  };
}
