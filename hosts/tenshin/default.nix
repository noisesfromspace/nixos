{ ... }:
{
  networking.hostName = "tenshin";

  imports = [
    ./modules/cyberchef.nix
    ./modules/ittools.nix
    ./modules/caddy.nix
    ./modules/ntp.nix
  ];

  hosts.caddy.enable = true;
  hosts.cyberchef.enable = true;
  hosts.it-tools.enable = true;
  hosts.prometheus.enable = true;
  hosts.ntp.enable = true;

  hosts.auditd.enable = false;
  nix-mineral.enable = false;

  hosts.borg = {
    enable = true;
    repository = "ssh://aebp8i08@aebp8i08.repo.borgbase.com/./repo";
  };

  hosts.openssh = {
    enable = true;
    allowUsers = [
      "martijn@100.64.0.0/10"
      "martijn@10.30.0.0/24"
    ];
  };

  nix.settings.trusted-users = [ "martijn" ]; # allows for remote push

  # Enable tailscale network
  hosts.tailscale.enable = true;

  # Server defaults
  hosts.server.enable = true;
}
