{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.hosts.laptop;
in
{
  options.hosts.laptop = {
    enable = mkEnableOption "Base laptop";
  };

  config = mkIf cfg.enable {
    services.tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 100;
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 50;
      };
    };

    services.logind.settings.Login = {
      # https://www.freedesktop.org/software/systemd/man/logind.conf.html
      HandleLidSwitch = "ignore";
    };

    boot.kernelParams = [ "i2c_hid.polling_mode=1" ];

    systemd.sleep.settings.Sleep = {
      HibernateDelaySec = "30m";
      SuspendState = "mem";
    };
  };
}
