{ pkgs, ... }:
{
  imports = [
    ../../home
  ];

  home.packages = with pkgs; [
    signal-cli
    stable.sdrpp # sdr
    # electrum
    android-tools
  ];

  programs.git.signing.signByDefault = false;
  programs.yt-dlp.enable = true;
  age.identityPaths = [ "/home/martijn/.ssh/id_ed25519_age" ];

  maatwerk.sync.work.enable = true;
  maatwerk.niri.enable = true;
}
