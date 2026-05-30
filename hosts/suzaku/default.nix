{ ... }:
{
  networking.hostName = "suzaku";

  imports = [
    ./modules/caddy.nix
    ./modules/hass.nix
  ];

  hosts.caddy.enable = true;
  hosts.hass.enable = true;
  nix-mineral.enable = false;
  hosts.auditd.enable = false;

  hosts.borg = {
    enable = true;
    repository = "ssh://jh49p12c@jh49p12c.repo.borgbase.com/./repo";
  };

  hosts.openssh = {
    enable = true;
    allowUsers = [
      "*@100.64.0.0/10"
      "*@10.30.0.0/24"
    ];
  };

  nix.settings.trusted-users = [ "martijn" ]; # allows for remote push

  # Enable tailscale network
  hosts.tailscale.enable = true;

  # Server defaults
  hosts.server.enable = true;
}
