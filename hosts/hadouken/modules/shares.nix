{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.hosts.shares;
in
{
  options.hosts.shares = {
    enable = mkEnableOption "Shares";
  };

  config = mkIf cfg.enable {
    fileSystems."/export/music" = {
      device = "/mnt/zwembad/music";
      fsType = "nfs";
      options = [ "bind" ];
    };

    fileSystems."/export/share" = {
      device = "/mnt/zwembad/share";
      fsType = "nfs";
      options = [ "bind" ];
    };

    boot.supportedFilesystems = [ "nfs" ];

    services.nfs.server = {
      enable = true;
      exports = ''
        /export          100.64.0.0/10(rw,fsid=0,no_subtree_check) 
        /export/music    100.64.0.0/10(rw,nohide,insecure,no_subtree_check)
        /export/share    100.64.0.0/10(rw,nohide,insecure,no_subtree_check)
      '';
    };
  };
}
