{ lib, ... }:
{
  networking.hostName = "tatsumaki";

  imports = [
    ./modules/adguard.nix
    ./modules/caddy.nix
  ];

  hosts.tailscale.enable = true;
  hosts.prometheus.enable = true;
  hosts.caddy.enable = true;
  hosts.adguard.enable = true;

  users.users.martijn = {
    hashedPasswordFile = lib.mkForce null;
    hashedPassword = "$y$j9T$VQL/82faMlZSrWg9SefdB/$RQpwhho.v0avZJcjate9yXdzDxVRdBBXeui7ch5XYm9";
  };

  hosts.openssh = {
    enable = true;
    allowUsers = [
      "*@100.64.0.0/10"
      "*@10.30.0.0/24"
    ];
  };

  hosts.borg = {
    enable = true;
    repository = "ssh://jym6959y@jym6959y.repo.borgbase.com/./repo";
  };

  nix.settings.trusted-users = [ "martijn" ]; # allows remote push

  # Server defaults
  hosts.server.enable = true;
}
