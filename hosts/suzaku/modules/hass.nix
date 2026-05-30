{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.hosts.hass;
in
{
  options.hosts.hass = {
    enable = mkEnableOption "Home assistant server";
  };

  config = mkIf cfg.enable {
    services.caddy.virtualHosts."hass.thuis".extraConfig = ''
      import headscale
      import mtls

      handle @internal {
        reverse_proxy http://127.0.0.1:${toString config.services.home-assistant.config.http.server_port}
      }
      respond 403
    '';
    services.borgbackup.jobs.default.paths = [ config.services.home-assistant.configDir ];
    services.home-assistant = {
      enable = true;
      extraPackages =
        python3Packages: with python3Packages; [
          ibeacon-ble # don't use the bluetooth stuff...
          hassil
          apprise
          numpy
          pyturbojpeg
          gtts
          aiohttp-fast-zlib
        ];
      extraComponents = [
        "shelly"
        "apprise"
        "isal"
        "cloud"
      ];
      config = {
        http = {
          use_x_forwarded_for = true;
          trusted_proxies = [
            "127.0.0.1"
          ];
        };
        notify = {
          name = "hass";
          platform = "apprise";
          url = "!secret gotify";
        };
        automation =
          let
            mkPowerNoti = sensor: below: message: {
              alias = message;
              trigger = [
                {
                  platform = "numeric_state";
                  entity_id = [ sensor ];
                  for = {
                    minutes = 5;
                  };
                  inherit below;
                }
              ];
              condition = [ ];
              action = [
                {
                  service = "notify.hass";
                  data.message = message;
                }
              ];
              mode = "single";
            };
          in
          [
            (mkPowerNoti "sensor.waterfontein_power" 1 "Otto did the boop")
            (mkPowerNoti "sensor.droger_power" 1 "Droger klaar")
            (mkPowerNoti "sensor.wasmachine_power" 1 "Wasmachine klaar")
          ];
        homeassistant = {
          name = "Thuis";
          unit_system = "metric";
          temperature_unit = "C";
          longitude = 52.081202;
          latitude = 4.306941;
        };
      };
    };
  };
}
