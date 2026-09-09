{
  config,
  lib,
  inputs,
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
    services.power-profiles-daemon.enable = true;

    age.secrets = {
      password-laptop.file = mkDefault "${inputs.secrets}/password-laptop.age";
    };

    services.logind.settings.Login = {
      # https://www.freedesktop.org/software/systemd/man/logind.conf.html
      HandleLidSwitch = "ignore";
    };

    boot.kernelParams = [ "i2c_hid.polling_mode=1" ];

    hosts.yubikey = {
      autolock = true;
    };

    security.pam = {
      services.sudo.unixAuth = true;
      services.polkit-1.unixAuth = true;
    };

    systemd.sleep.settings.Sleep = {
      HibernateDelaySec = "30m";
      SuspendState = "mem";
    };
  };
}
