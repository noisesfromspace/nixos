{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.media;
  mkProxy = port: ''
    import headscale
    handle @internal {
      reverse_proxy http://127.0.0.1:${toString port}
    }
    respond 403
  '';

  proxyUrl = "http://10.98.0.2:${toString config.hosts.netns.http.port}";
  proxyEnv = {
    http_proxy = proxyUrl;
    https_proxy = proxyUrl;
    HTTP_PROXY = proxyUrl;
    HTTPS_PROXY = proxyUrl;
    no_proxy = "127.0.0.1,localhost,10.98.0.1,10.98.0.2,.thuis,.machine.thuis";
    NO_PROXY = "127.0.0.1,localhost,10.98.0.1,10.98.0.2,.thuis,.machine.thuis";
  };

in
{
  options.hosts.media = {
    enable = mkEnableOption "media services";
  };

  config = mkIf cfg.enable {
    users.groups = {
      render.members = [ "jellyfin" ];
      multimedia.members = [
        "jellyfin"
        "martijn"
        "radarr"
        "sonarr"
        "transmission"
      ];
    };

    nixpkgs.overlays = [
      (final: prev: {
        jellyfin-ffmpeg = prev.jellyfin-ffmpeg.override {
          ffmpeg_7-full = prev.ffmpeg_7-full.override {
            withMfx = false; # Disable the old MFX
            withVpl = true; # Enable the new VPL
            withUnfree = true;
          };
        };
      })
    ];

    environment.systemPackages = [ pkgs.jellyfin-ffmpeg ];

    boot.kernel.sysctl = {
      "fs.inotify.max_user_watches" = 524288;
      # For QUIC/UDP Buffer Size
      "net.core.rmem_max" = 2500000;
      "net.core.wmem_max" = 2500000;
    };

    systemd = {
      tmpfiles.rules = [
        # Type, Path,                       Mode, Owner,    Group,      Age, Argument
        "d /mnt/zwembad/hot/Downloads -     2775  martijn   multimedia  -    -"
        "d /mnt/zwembad/hot/Movies    -     2775  martijn   multimedia  -    -"
        "d /mnt/zwembad/hot/Series    -     2775  martijn   multimedia  -    -"
        "d /mnt/zwembad/music         -     2775  martijn   multimedia  -    -"
      ];

      services.unpackerr = {
        description = "Unpackerr";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          User = "transmission";
          Group = "multimedia";
          UMask = "0002";
          EnvironmentFile = config.age.secrets.unpackerr.path;
          ExecStart =
            let
              config = pkgs.writeText "unpackerr.conf" ''
                [[sonarr]]
                url = "https://sonarr.thuis"
                [[radarr]]
                url = "https://radarr.thuis"
              '';
            in
            "${lib.getExe pkgs.unpackerr} -c ${config}";
          Restart = "on-failure";
        };
      };
    };

    age.secrets.unpackerr.file = "${inputs.secrets}/unpackerr.age";

    systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD";
    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };

    hosts.netns.allowedIngressPorts = [ 9091 ];

    services = {
      jellyfin.enable = true;
      seerr.enable = true;

      transmission = {
        enable = true;
        package = pkgs.transmission_4;
        group = "multimedia";
        settings = {
          rpc-bind-address = "10.98.0.2";
          download-dir = "/mnt/zwembad/hot/Downloads";
          incomplete-dir-enabled = false;
          port-forwarding-enabled = false;
          rpc-whitelist = "127.0.0.1,10.98.0.1";
          rpc-host-whitelist-enabled = false;
          message-level = 1;
        };
      };

      borgbackup.jobs.default.paths = [
        config.services.prowlarr.dataDir
        config.services.radarr.dataDir
        config.services.sonarr.dataDir
        config.services.jellyfin.dataDir
      ];

      prowlarr = {
        enable = true;
        settings.server.bindaddress = "127.0.0.1";
      };

      caddy.virtualHosts = {
        "media.thuis" = {
          extraConfig = mkProxy 8096;
        };
        "radarr.thuis" = {
          extraConfig = mkProxy config.services.radarr.settings.server.port;
        };
        "sonarr.thuis" = {
          extraConfig = mkProxy config.services.sonarr.settings.server.port;
        };
        "prowlarr.thuis" = {
          extraConfig = mkProxy config.services.prowlarr.settings.server.port;
        };
        "transmission.thuis" = {
          extraConfig = ''
            import headscale
            handle @internal {
              reverse_proxy http://10.98.0.2:9091
            }
            respond 403
          '';
        };
      };
    }
    // (genAttrs [ "radarr" "sonarr" ] (name: {
      enable = true;
      group = "multimedia";
      settings.server.bindaddress = "127.0.0.1";
    }));

    systemd.services.transmission = {
      bindsTo = [ "netns@tunnel.service" ];
      after = [
        "netns@tunnel.service"
        "wireguard-tun0.service"
      ];
      serviceConfig = {
        NetworkNamespacePath = "/var/run/netns/tunnel";
        BindPaths = lib.mkAfter [
          "/mnt/zwembad/music"
        ];
        BindReadOnlyPaths = lib.mkAfter [
          "${pkgs.writeText "tunnel-resolv.conf" "nameserver 10.64.0.1"}:/etc/resolv.conf"
        ];
      };
    };
    systemd.services.prowlarr.environment = proxyEnv;
    systemd.services.radarr.environment = proxyEnv;
    systemd.services.sonarr.environment = proxyEnv;
  };
}
