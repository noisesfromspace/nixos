{ ... }:
{
  networking.hostName = "tatsumaki";

  imports = [
    ./modules/adguard.nix
    ./modules/backup.nix
    ./modules/caddy.nix
    ./modules/ladder.nix
  ];

  hosts.tailscale.enable = true;
  hosts.caddy.enable = true;
  hosts.adguard.enable = true;
  hosts.ladder.enable = true;

  hosts.openssh = {
    enable = true;
    allowUsers = [
      "martijn@100.64.0.0/10"
      "martijn@10.30.0.0/24"
    ];
  };

  hosts.borg = {
    enable = true;
    repository = "ssh://jym6959y@jym6959y.repo.borgbase.com/./repo";
  };

  hosts.borg-server = {
    enable = true;
    clients = [
      "nurma"
      "hadouken"
      "suzaku"
      "tenshin"
      "paddy"
      "donk"
      "dosukoi"
      "rekkaken"
    ];
  };

  nix.settings.trusted-users = [ "martijn" ]; # allows remote push

  # Server defaults
  hosts.server.enable = true;
}
