{
  lib,
  config,
  ...
}:
{
  networking.hostName = "paddy";

  hosts = {
    desktop.enable = true;
    laptop.enable = true;
    secureboot.enable = true;
    tailscale.enable = true;
    yubikey = {
      enable = true;
      autolock = true;
    };
  };

  age.identityPaths = [ "/home/martijn/.ssh/id_ed25519" ];

  hosts.borg = {
    enable = true;
    repository = "ssh://nkhm1dhr@nkhm1dhr.repo.borgbase.com/./repo";
    identityPath = "/home/martijn/.ssh/id_ed25519";
    paths = [ "/home/martijn" ];
    exclude = [
      ".cache"
      "*/cache2" # librewolf
      "*/Cache"
      ".wine"
      ".config/Slack/logs"
      ".config/Code/CachedData"
      ".container-diff"
      ".npm/_cacache"
      "*/node_modules"
      "*/_build"
      "*/venv"
      "*/.venv"
      "/home/*/.local"
      "/home/*/Downloads"
      "/home/*/Data"
      "/home/*/.ssh"
    ];
  };

  users.users.martijn = {
    hashedPasswordFile = lib.mkForce config.age.secrets.password-laptop.path;
  };
}
