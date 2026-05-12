# !! Not in use, potentially outdated !!
{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.hosts.nymvpn;
in
{
  options.hosts.nymvpn = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the NymVPN daemon (nym-vpnd) service.";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.nym-vpnd;
      description = "Override package providing nym-vpnd binary.";
    };

    socksPort = mkOption {
      type = types.int;
      default = 1080;
      description = "Local SOCKS5 listen port (bound to 127.0.0.1).";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/nym-vpnd";
      description = "Data directory for nym-vpnd (maps to NYM_VPND_DATA_DIR).";
    };

    logDir = mkOption {
      type = types.path;
      default = "/var/log/nym-vpnd";
      description = "Log directory for nym-vpnd (maps to NYM_VPND_LOG_DIR).";
    };

    exitCountry = mkOption {
      type = types.str;
      default = "BE";
      description = "Default exit country for SOCKS5 and VPN.";
    };

    autoStartSocks = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically enable SOCKS5 proxy on service start.";
    };

    autoConnect = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically connect system-wide VPN on service start.";
    };

    residentialExit = mkOption {
      type = types.bool;
      default = false;
      description = "Only use residential exit nodes.";
    };

    dnsServers = mkOption {
      type = types.listOf types.str;
      default = [
        "9.9.9.9"
        "149.112.112.112"
      ];
      description = "Custom DNS servers to use when connected.";
    };

    disableIPv6 = mkOption {
      type = types.bool;
      default = false;
      description = "Disable IPv6 inside the Nym tunnel to prevent leaks.";
    };

  };

  config = mkIf cfg.enable {
    systemd.services.nym-vpnd = {
      description = "NymVPN daemon";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "NetworkManager.service"
        "systemd-resolved.service"
      ];
      path = with pkgs; [
        iproute2
        nftables
        cfg.package # ensure nym-vpnc is in path for postStart
      ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/nym-vpnd -v run-as-service";
        Restart = "always";
        RestartSec = "2";
        WorkingDirectory = "/";
        RuntimeDirectory = "nym-vpnd";
        StateDirectory = "nym-vpnd";
        Environment = lib.concatStringsSep " " [
          "NYM_VPND_CONFIG_DIR=%S/etc"
          "NYM_VPND_DATA_DIR=${cfg.dataDir}"
          "NYM_VPND_LOG_DIR=${cfg.logDir}"
          "NYM_VPND_SOCKS_LISTEN=127.0.0.1:${toString cfg.socksPort}"
          "NYM_VPND_SOCKS5_IDLE_TIMEOUT_SECS=86400" # 24h idle timeout to prevent disconnection
          "NYM_VPND_SOCKS5_REQUEST_TIMEOUT_SECS=60" # Increased request timeout for mixnet latency
        ];
        CapabilityBoundingSet = [
          "CAP_NET_ADMIN"
          "CAP_NET_BIND_SERVICE"
        ];
        AmbientCapabilities = [
          "CAP_NET_ADMIN"
          "CAP_NET_BIND_SERVICE"
        ];
        DeviceAllow = [ "/dev/net/tun rw" ];

        # Hardening
        ProtectSystem = "full";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        MemoryDenyWriteExecute = true;
      };

      postStart = ''
        # Wait for the daemon to be ready
        for i in {1..10}; do
          ${cfg.package}/bin/nym-vpnc status >/dev/null 2>&1 && break
          sleep 1
        done

        # Configure DNS
        ${cfg.package}/bin/nym-vpnc dns set ${concatStringsSep " " cfg.dnsServers} || true
        ${cfg.package}/bin/nym-vpnc dns enable || true

        # Configure IPv6 and Routing
        ${cfg.package}/bin/nym-vpnc tunnel set --ipv6 ${if cfg.disableIPv6 then "off" else "on"} || true
        ${cfg.package}/bin/nym-vpnc gateway set --residential-exit ${
          if cfg.residentialExit then "on" else "off"
        } || true

        ${optionalString cfg.autoStartSocks ''
          ${cfg.package}/bin/nym-vpnc socks5 enable --socks5-address 127.0.0.1:${toString cfg.socksPort} --exit-country ${cfg.exitCountry} || true
        ''}
        ${optionalString cfg.autoConnect ''
          ${cfg.package}/bin/nym-vpnc gateway set --exit-country ${cfg.exitCountry} || true
          ${cfg.package}/bin/nym-vpnc connect || true
        ''}
      '';
    };

    environment.systemPackages = [ (cfg.package) ];
  };
}
