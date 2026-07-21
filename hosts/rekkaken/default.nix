{
  ...
}:
{
  networking.hostName = "rekkaken";

  imports = [
    ./modules/headscale.nix
    ./modules/notifs.nix
    ./modules/uptime.nix
    ./modules/ladder.nix
    ./modules/caddy.nix
  ];

  hosts.headscale.enable = true;
  hosts.notifications.enable = true;
  hosts.caddy.enable = true;
  hosts.uptime-kuma.enable = true;
  hosts.prometheus.enable = true;
  hosts.ladder.enable = true;
  hosts.tailscale.enable = true;

  hosts.stalwart = {
    enable = true;
    nodeId = 2;
  };

  hosts.derper = {
    enable = true;
    domain = "derp2.boers.email";
  };

  hosts.authdns = {
    enable = true;
    master = true;
  };

  hosts.openssh = {
    enable = true;
    allowUsers = [
      "martijn@100.64.0.0/10"
    ];
  };

  hosts.borg = {
    enable = true;
    repository = "ssh://c4j3xt27@c4j3xt27.repo.borgbase.com/./repo";
  };

  nix.settings.trusted-users = [ "martijn" ]; # allows remote push

  # Server defaults
  hosts.server.enable = true;
}
