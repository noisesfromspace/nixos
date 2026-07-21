{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.hosts.borg-server;
in
{
  options.hosts.borg-server = {
    enable = mkEnableOption "Host borg repositories on /mnt/evo";
    clients = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Hosts allowed to back up here (public key read from secrets/keys/<name>.pub)";
      example = [ "nurma" ];
    };
  };

  config = mkIf cfg.enable {
    # One repo per client. Keys are append-only: a compromised client cannot
    # permanently delete backups, space is reclaimed by borg compact below.
    services.borgbackup.repos = genAttrs cfg.clients (name: {
      path = "/mnt/evo/borg/${name}";
      authorizedKeysAppendOnly = [
        (readFile "${inputs.secrets}/keys/${name}.pub")
      ];
    });

    # Append-only means client-side prune only marks archives as deleted;
    # compact (outside the append-only restriction) actually reclaims space.
    age.secrets.borg = {
      group = mkForce "borg";
      mode = mkForce "0440";
    };
    systemd.services.borg-compact = {
      description = "Reclaim space in append-only borg repositories";
      startAt = "weekly";
      path = [ pkgs.borgbackup ];
      environment.BORG_PASSCOMMAND = "cat ${config.age.secrets.borg.path}";
      serviceConfig = {
        Type = "oneshot";
        User = "borg";
      };
      script = ''
        shopt -s nullglob
        for repo in /mnt/evo/borg/*; do
          borg compact "$repo"
        done
      '';
    };
  };
}
