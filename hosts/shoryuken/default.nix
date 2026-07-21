{ ... }:
{
  networking.hostName = "shoryuken";

  imports = [
    ./modules/endlessh.nix
    ./modules/radicle.nix
    ./modules/umami.nix
    ./modules/caddy.nix
  ];

  hosts.oidc = {
    enable = true;
    domain = "auth.boers.email";
  };

  hosts.caddy.enable = true;
  hosts.umami.enable = true;
  hosts.prometheus.enable = true;
  hosts.endlessh.enable = true;
  hosts.radicle.enable = true;
  hosts.authdns.enable = true;

  hosts.stalwart = {
    enable = true;
    nodeId = 1;
  };

  hosts.derper = {
    enable = true;
    domain = "derp1.boers.email";
  };

  # Enable tailscale network
  hosts.tailscale.enable = true;

  hosts.openssh = {
    enable = true;
    allowUsers = [
      "martijn@100.64.0.0/10"
    ];
  };

  hosts.borg = {
    enable = true;
    repository = "ssh://iwa7rtli@iwa7rtli.repo.borgbase.com/./repo";
  };

  services.borgbackup.jobs.default.paths = [ "/var/lib/postgresql" ];

  nix.settings.trusted-users = [ "martijn" ]; # allows remote push

  # Server defaults
  hosts.server.enable = true;
}
