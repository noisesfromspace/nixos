{ pkgs, ... }:
{
  imports = [
    ../../home
  ];

  home.packages = with pkgs; [
    zfs
    stable.veracrypt
  ];

  maatwerk.pi = {
    enable = true;
    server.enable = true;
  };

  maatwerk.sync = {
    enable = true;
    sessions.enable = false;
    work.enable = false;
  };

}
