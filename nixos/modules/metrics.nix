{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.hosts.metrics;
  retentionTime = 30 * 6;
in
{
  options.hosts.metrics = {
    enable = mkEnableOption "Enable endpoint protection";
    tetragon = {
      metricsPort = mkOption {
        type = types.int;
        default = 2113;
        description = "Port for Tetragon Prometheus metrics";
      };
      exportDir = mkOption {
        type = types.str;
        default = "/var/log/tetragon";
        description = "Directory for JSON event export";
      };
    };
  };

  config = mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      port = 9001;
      retentionTime = toString retentionTime + "d";
      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = 9002;
        };
      };
    };

    systemd.services.tetragon = {
      description = "Tetragon eBPF Runtime Security";
      documentation = [ "https://tetragon.io/docs" ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.tetragon}/bin/tetragon --metrics-server :${toString cfg.tetragon.metricsPort} --export-filename ${cfg.tetragon.exportDir}/tetragon.log --export-file-max-size-mb 50 --export-file-max-backups 5 --export-file-compress --export-file-perm 644 --server-address unix:///var/run/tetragon/tetragon.sock";
        Restart = "always";
        RestartSec = 10;
        RuntimeDirectory = "tetragon";
        LogsDirectory = "tetragon";
        ReadWritePaths = cfg.tetragon.exportDir;
      };
    };

    # Ship logs to Loki on hadouken via Grafana Alloy
    services.alloy = {
      enable = true;
      extraFlags = [
        "--storage.path=/var/lib/alloy"
        "--server.http.listen-addr=127.0.0.1:12345"
      ];
    };

    # Alloy DynamicUser can't read /var/log/tetragon by default
    systemd.services.alloy.serviceConfig.ReadOnlyPaths = [ cfg.tetragon.exportDir ];

    environment.etc."alloy/config.alloy".text = ''
      // ── Journald → Loki (line = MESSAGE only, no JSON blob) ──
      loki.source.journal "journald" {
        forward_to    = [loki.write.default.receiver]
        format_as_json = false
        labels        = { job = "journald" }
        relabel_rules = loki.relabel.journald.rules
      }

      loki.relabel "journald" {
        forward_to = []

        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }
        rule {
          source_labels = ["__journal_priority_keyword"]
          target_label  = "level"
        }
        rule {
          source_labels = ["__journal__hostname"]
          target_label  = "host"
        }
      }

      // ── Tetragon JSON logs → Loki (parsed into labels + structured metadata) ──
      loki.source.file "tetragon" {
        targets = [{
          __path__ = "${cfg.tetragon.exportDir}/tetragon.log",
          job      = "tetragon",
          host     = "${config.networking.hostName}",
        }]
        forward_to = [loki.process.tetragon_parse.receiver]
      }

      loki.process "tetragon_parse" {
        forward_to = [loki.write.default.receiver]

        stage.json {
          regex = "^(process_exec|process_exit)$"
          expressions = {
            pid    = "process_exec.process.pid || process_exit.process.pid",
            uid    = "process_exec.process.uid || process_exit.process.uid",
            binary = "process_exec.process.binary || process_exit.process.binary",
          }
        }

        stage.template {
          source   = "event_type"
          template = "{{ if .process_exec }}process_exec{{ else if .process_exit }}process_exit{{ end }}"
        }

        stage.labels {
          values = { event_type = "" }
        }

        stage.structured_metadata {
          values = { pid = "", uid = "", binary = "" }
        }
      }

      loki.write "default" {
        endpoint {
          url = "https://loki.thuis/loki/api/v1/push"
        }
      }
    '';
  };
}
