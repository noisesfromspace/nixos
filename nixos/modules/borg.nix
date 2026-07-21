{
  config,
  lib,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.borg;
  mkJob = repo: {
    paths = cfg.paths;
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.age.secrets.borg.path}";
    };
    prune.keep = {
      within = "15d"; # Keep all archives from the last 15 days
      monthly = -1; # Keep at least one archive for each month
    };
    environment.BORG_RSH = "ssh -i ${cfg.identityPath}";
    inherit repo;
    compression = "auto,zstd";
    startAt = "12:30";
    user = "root";
    exclude = cfg.exclude;
  };
in
{
  options.hosts.borg = {
    enable = mkEnableOption "Make backups of host";
    repository = mkOption {
      type = types.str;
      description = "Repository link";
    };
    exclude = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Exclude these paths";
    };
    paths = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Include these paths";
    };
    identityPath = mkOption {
      type = types.str;
      default = "/home/martijn/.ssh/id_ed25519";
      description = "Which key to use";
    };
    tatsumaki = mkEnableOption "Also back up to tatsumaki (/mnt/evo)";
  };

  config = mkIf cfg.enable {
    age.secrets.borg = {
      file = "${inputs.secrets}/borg.age";
      owner = "root";
      group = "root";
    };
    # Repo path is ".": the authorized_keys forced command on tatsumaki
    # cd's into this host's repo and runs borg serve --restrict-to-repository .
    services.borgbackup.jobs = {
      default = mkJob cfg.repository;
    }
    // optionalAttrs cfg.tatsumaki {
      tatsumaki = (mkJob "borg@tatsumaki.machine.thuis:.") // {
        startAt = "13:30"; # run after the primary job
      };
    };
  };
}
