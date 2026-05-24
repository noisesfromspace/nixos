{ pkgs, ... }:
{
  imports = [
    ../../home
  ];

  home.packages = with pkgs; [
    zfs
    stable.veracrypt
  ];
  maatwerk.pi.enable = true;

}
