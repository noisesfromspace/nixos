{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.kasm;
  kasmPort = 9443;
in
{
  options.hosts.kasm = {
    enable = mkEnableOption "Kasm workspaces (containerized apps/desktops)";
  };

  config = mkIf cfg.enable {
    services.caddy.virtualHosts."kasm.thuis".extraConfig = ''
      import headscale
      handle @internal {
        reverse_proxy https://127.0.0.1:${toString kasmPort} {
          transport http {
            tls_insecure_skip_verify
          }
          header_up Host {http.request.host}
          header_up X-Forwarded-Port "443"
          header_up X-Forwarded-Proto "https"
        }
      }
      respond 403
    '';

    services.kasmweb = {
      enable = true;
      listenAddress = "127.0.0.1";
      listenPort = kasmPort;
      datastorePath = "/mnt/zwembad/games/kasm";
      sslCertificate = null;
      sslCertificateKey = null;
      defaultAdminPassword = "kasmweb";
      defaultUserPassword = "kasmweb";
      defaultGuacToken = "kasmweb";
      defaultManagerToken = "kasmweb";
      defaultRegistrationToken = "kasmweb";
      redisPassword = "kasmweb";
    };

    virtualisation.docker = {
      enable = true;
      daemon.settings = {
        data-root = "/mnt/zwembad/games/containers";
      };
    };

    # Fix kasmguac config: the nixpkgs init script only replaces GUACTOKEN/APIHOSTNAME
    # but the template uses REGISTRATION_TOKEN/JWTTOKEN/PUBLICCERT. Patch after init.
    systemd.services.init-kasmweb.serviceConfig.ExecStartPost = [
      (pkgs.writeShellScript "fix-kasmguac-config" ''
        set -e
        CFG=/mnt/zwembad/games/kasm/conf/app/kasmguac.app.config.yaml
        if [ ! -f "$CFG" ]; then exit 0; fi

        # Set registration_token and auth_token
        ${pkgs.yq-go}/bin/yq -i '.kasmguac.registration_token = "kasmweb"' "$CFG"
        ${pkgs.yq-go}/bin/yq -i '.api.auth_token = "kasmweb"' "$CFG"

        # Fetch the JWT public cert from the DB
        Q="select value from settings where name='api_public_cert';"
        CERT=$(${pkgs.docker}/bin/docker exec kasm_db \
          psql -U postgres -d kasm -A -t \
          -c "$Q" 2>/dev/null || true)
        if [ -n "$CERT" ]; then
          ${pkgs.yq-go}/bin/yq -i ".api.public_jwt_cert = \"$CERT\"" "$CFG"
        fi

        # Fill other required fields
        ${pkgs.yq-go}/bin/yq -i '.kasmguac.cluster_size = 1' "$CFG"
        ${pkgs.yq-go}/bin/yq -i '.kasmguac.server_address = "kasm_api"' "$CFG"
        ${pkgs.yq-go}/bin/yq -i '.kasmguac.server_port = 8080' "$CFG"
        ${pkgs.yq-go}/bin/yq -i '.kasmguac.zone = "default"' "$CFG"
      '')
    ];

    # Ensure the data directory exists
    systemd.tmpfiles.rules = [
      "d /mnt/zwembad/games/kasm 0750 root root -"
    ];
  };
}