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

  hosts.netns.socks5.enable = true;
  age.identityPaths = [ "/home/martijn/.ssh/id_ed25519" ];

  hosts.borg = {
    enable = true;
    repository = "ssh://zzhbsr2v@zzhbsr2v.repo.borgbase.com/./repo";
    identityPath = "/home/martijn/.ssh/id_ed25519";
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
}
