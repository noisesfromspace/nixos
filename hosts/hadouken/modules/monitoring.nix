{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.monitoring;
in
{
  options.hosts.monitoring = {
    enable = mkEnableOption "Enable monitoring to host";
  };

  config = mkIf cfg.enable {
    services.caddy.virtualHosts."monitoring.thuis".extraConfig = ''
      import headscale
      handle @internal {
        reverse_proxy http://127.0.0.1:${toString config.services.grafana.settings.server.http_port}
      }
      respond 403
    '';

    age.secrets.grafana = {
      file = "${inputs.secrets}/grafana.age";
      owner = "grafana";
    };

    services.borgbackup.jobs.default.paths = [ config.services.grafana.settings.database.path ];

    services.grafana = {
      enable = true;
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${toString config.services.prometheus.port}";
          }
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
          }
        ];
      };
      settings = {
        security.secret_key = "$__file{${config.age.secrets.grafana.path}}";
        server = {
          domain = "monitoring.thuis";
          http_port = 2342;
          http_addr = "127.0.0.1";
        };
        analytics.reporting_enabled = false;
      };
      declarativePlugins = with pkgs.grafanaPlugins; [ grafana-piechart-panel ];
    };

    services.loki = {
      enable = true;
      configuration = {
        server.http_listen_port = 3030;
        auth_enabled = false;
        analytics.reporting_enabled = false;

        common = {
          ring = {
            instance_addr = "127.0.0.1";
            kvstore.store = "inmemory";
          };
          replication_factor = 1;
          path_prefix = "/tmp/loki";
        };

        schema_config = {
          configs = [
            {
              from = "2020-05-15";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
        };
        storage_config.filesystem.directory = "/mnt/zwembad/games/loki/chunk";
      };
    };

    services.prometheus = {
      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets =
                map (host: "${host}.machine.thuis:${toString config.services.prometheus.exporters.node.port}")
                  [
                    "hadouken"
                    "shoryuken"
                    "tatsumaki"
                    "tenshin"
                    "rekkaken"
                    "nurma"
                    "dosukoi"
                  ];
            }
          ];
        }
        {
          job_name = "caddy";
          static_configs = [
            {
              targets = map (host: "${host}.machine.thuis:2019") [
                "dosukoi"
                "hadouken"
                "tatsumaki"
                "tenshin"
                "rekkaken"
                "shoryuken"
              ];
            }
          ];
        }
        {
          job_name = "endlessh";
          static_configs = [
            {
              targets = [ "shoryuken.machine.thuis:${toString config.services.endlessh-go.prometheus.port}" ];
            }
          ];
        }
      ];
    };
  };
}
