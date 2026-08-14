{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.hosts.proxy;
in
{
  options.hosts.proxy = {
    enable = mkEnableOption "Tailnet HTTP proxy for clean-IP federation egress";
  };

  config = mkIf cfg.enable {
    # Forward HTTP(S) proxy reachable over the tailnet. Matrix and Mastodon
    # point their http_proxy here so federation egresses from shoryuken's
    # public IP rather than Mullvad (some servers block VPN ranges).
    #
    # Access control: hosts.tailscale marks tailscale0 as a trusted firewall
    # interface and the public interface keeps the default drop policy, so
    # only tailnet clients can reach 8118. The Allow list is app-level
    # defense in depth.
    services.tinyproxy = {
      enable = true;
      settings = {
        Listen = "0.0.0.0";
        Port = 8118;
        MaxClients = 5000;
        Allow = [ "100.64.0.0/10" ];
      };
    };

    # MaxClients=5000 needs ~10k fds (two per tunneled connection).
    systemd.services.tinyproxy.serviceConfig.LimitNOFILE = 16384;
  };
}
