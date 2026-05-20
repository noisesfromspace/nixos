{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.litellm;
  litellmPort = 8080;
  configFile = pkgs.writeText "litellm-config.yaml" ''
    general_settings:
      master_key: os.environ/LITELLM_MASTER_KEY
      database_url: os.environ/DATABASE_URL
  '';
in
{
  options.hosts.litellm = {
    enable = mkEnableOption "LiteLLM proxy gateway";
  };

  config = mkIf cfg.enable {
    virtualisation.podman.enable = true;

    services.caddy.virtualHosts."litellm.thuis".extraConfig = ''
      import headscale
      handle @internal {
        reverse_proxy http://localhost:${toString litellmPort}
      }
      respond 403
    '';

    age.secrets.litellm.file = "${inputs.secrets}/litellm.age";

    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers.litellm = {
      image = "docker.litellm.ai/berriai/litellm:main-latest";
      autoStart = true;
      environment = {
        DATABASE_URL = "postgresql://litellm@127.0.0.1:5432/litellm";
      };
      environmentFiles = [ config.age.secrets.litellm.path ];
      volumes = [
        "${configFile}:/app/config.yaml:ro"
      ];
      cmd = [
        "--config"
        "/app/config.yaml"
        "--port"
        (toString litellmPort)
        "--host"
        "127.0.0.1"
      ];
      extraOptions = [ "--network=host" ];
    };

    systemd.services.podman-litellm = {
      after = [
        "network-online.target"
        "postgresql.service"
      ];
      requires = [ "postgresql.service" ];
    };
  };
}
