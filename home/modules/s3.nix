{
  config,
  lib,
  inputs,
  ...
}:
with lib;
let
  cfg = config.maatwerk.s3;
in
{
  options.maatwerk.s3 = {
    enable = mkEnableOption "Garage S3 access (random bucket) via rclone";
  };

  config = mkIf cfg.enable {
    age.secrets.garage-s3 = {
      file = "${inputs.secrets}/garage-s3.age";
      mode = "400";
    };

    programs.rclone = {
      enable = true;
      remotes.garage = {
        config = {
          type = "s3";
          provider = "Other";
          env_auth = false;
          endpoint = "https://garage.thuis";
          region = "thuis";
          force_path_style = true;
          access_key_id = "GK46f2f34ed90345c2292be268";
        };
        secrets = {
          secret_access_key = config.age.secrets.garage-s3.path;
        };
      };
    };
  };
}
