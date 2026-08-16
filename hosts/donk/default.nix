{
  lib,
  config,
  ...
}:
{
  networking.hostName = "donk";
  hosts.desktop.enable = true;
  hosts.laptop.enable = true;
  hosts.secureboot.enable = true;

  age.identityPaths = [ "/home/martijn/.ssh/id_ed25519" ];

  programs.ssh.extraConfig = ''
    Host eu.nixbuild.net
      PubkeyAcceptedKeyTypes ssh-ed25519
      ServerAliveInterval 60
      IPQoS throughput
      IdentityFile /home/martijn/.ssh/my-nixbuild-key
  '';

  # nix = {
  #   settings = {
  #     substituters = [ "ssh://eu.nixbuild.net" ];
  #     trusted-public-keys = [
  #       "nixbuild.net/HCCJGO-1:CJ14jk1iYfkrCFCxEJXuaozznRwCIbvgQymwWZW3t94="
  #     ];
  #   };
  # };

  hosts.borg = {
    enable = true;
    repository = "ssh://iuyrg38x@iuyrg38x.repo.borgbase.com/./repo";
    identityPath = "/home/martijn/.ssh/id_ed25519_age";
    tatsumaki = true;
    paths = [
      "/home/martijn/Pictures"
      "/home/martijn/Documents"
      "/home/martijn/Videos"
    ];
  };

  users.users.martijn = {
    hashedPasswordFile = lib.mkForce config.age.secrets.password-laptop.path;
  };

  hosts.tailscale.enable = true;

  # Enable binfmt emulation of aarch64-linux. (for the raspberry pi)
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Support gpg for git signing
  hosts.yubikey.enable = true;
}
