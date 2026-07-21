{
  ...
}:
{
  networking.hostName = "dosukoi";

  imports = [
    ./modules/vaultwarden.nix
    ./modules/interfaces.nix
    ./modules/wireguard.nix
    ./modules/blocklist.nix
    ./modules/firewall.nix
    ./modules/ntopng.nix
    ./modules/caddy.nix
    ./modules/acme.nix
  ];

  hosts.borg = {
    enable = true;
    repository = "ssh://llh048o5@llh048o5.repo.borgbase.com/./repo";
  };

  nix.settings.trusted-users = [ "martijn" ]; # allows remote push
  hosts.server.enable = true;
  hosts.caddy.enable = true;
  hosts.ntopng.enable = true;
  hosts.wireguard.enable = true;
  hosts.vaultwarden.enable = true;
  hosts.acme.enable = true;

  hosts.oidc = {
    enable = true;
    internal = true;
    domain = "auth.thuis";
  };

  hosts.openssh = {
    enable = true;
    allowUsers = [
      "martijn@100.64.0.0/10"
      "martijn@10.30.0.0/24"
    ];
  };

  hosts.tailscale.enable = true;
  hosts.prometheus.enable = true;

  age = {
    identityPaths = [ "/home/martijn/.ssh/id_ed25519" ];
  };
}
