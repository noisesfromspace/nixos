{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.llmgateway;

  # Pinned upstream image tag — bump deliberately.
  # https://github.com/theopenco/llmgateway/releases
  imageTag = "latest";

  # User-defined podman network with an explicit subnet so we know which
  # CIDR to allow in pg_hba (see database.nix: 10.89.0.0/16).
  networkName = "llmgateway";
  networkSubnet = "10.89.1.0/24";

  # Runtime-built env files (assembled by the llmgateway-env oneshot below).
  runtimeDir = "/run/llmgateway";
  providerEnvFile = "${runtimeDir}/providers.env"; # LLM_* prefixed provider keys
  redisPwFile = "${runtimeDir}/redis.pw"; # plain password, for services.redis

  # Shared env applied to every app container.
  commonEnv = {
    NODE_ENV = "production";
    PORT = "80";
    # Public-facing URLs (used for OAuth redirects, CORS, cookies).
    UI_URL = "https://llm.thuis";
    API_URL = "https://llm-api.thuis";
    PLAYGROUND_URL = "https://llm-playground.thuis";
    DOCS_URL = "https://llm-docs.thuis";
    ADMIN_URL = "https://llm-admin.thuis";
    CODE_URL = "https://llm-code.thuis";
    ORIGIN_URLS = "https://llm.thuis,https://llm-api.thuis,https://llm-playground.thuis,https://llm-admin.thuis,https://llm-code.thuis";
    COOKIE_DOMAIN = "thuis";
    PASSKEY_RP_ID = "llm.thuis";
    PASSKEY_RP_NAME = "LLMGateway";
    # Inter-container service-to-service URL — podman's DNS resolves "api"
    # because all containers share the same user-defined network.
    API_BACKEND_URL = "http://api:80";
  };

  # DB and Redis live on the host. Containers reach them via the podman bridge
  # gateway, which podman exposes as host.containers.internal when we add
  # --add-host=host.containers.internal:host-gateway.
  hostGw = "host.containers.internal";
  databaseUrl = "postgres://llmgateway@${hostGw}:5432/llmgateway";

  # Helper to build an oci-containers entry.
  mkApp =
    {
      name,
      image,
      port,
      extraEnv ? { },
      dependsOn ? [ ],
    }:
    {
      inherit image dependsOn;
      autoStart = true;
      extraOptions = [
        "--network=${networkName}"
        "--network-alias=${name}"
        "--add-host=${hostGw}:host-gateway"
      ];
      environment = commonEnv // extraEnv;
      environmentFiles = [
        providerEnvFile # LLM_* provider keys rewritten from llm.age
        config.age.secrets.llmgateway.path # AUTH_SECRET, GATEWAY_API_KEY_HASH_SECRET, REDIS_PASSWORD, OAuth...
      ];
      ports = [ "127.0.0.1:${toString port}:80" ];
    };

  # Caddy snippet body for a simple reverse_proxy vhost.
  vhost = upstreamPort: ''
    import headscale
    handle @internal {
      reverse_proxy http://127.0.0.1:${toString upstreamPort}
    }
    respond 403
  '';

  # Shared systemd dependency set applied to every llmgateway-* container unit.
  containerDeps = {
    after = [
      "llmgateway-env.service"
      "podman-network-llmgateway.service"
      "postgresql.service"
      "redis-llmgateway.service"
    ];
    requires = [
      "llmgateway-env.service"
      "podman-network-llmgateway.service"
      "postgresql.service"
      "redis-llmgateway.service"
    ];
  };
in
{
  options.hosts.llmgateway = {
    enable = mkEnableOption "Self-hosted LLMGateway (theopenco/llmgateway split deployment)";
  };

  config = mkIf cfg.enable {
    # ---------------------------------------------------------------- secrets
    age.secrets = {
      # Existing repo-wide LLM provider keys (OPENAI_API_KEY=..., etc.)
      # We redefine the secret here (in addition to worker.nix) because
      # llmgateway containers run as root via podman and the env-rewrite
      # oneshot needs a root-readable copy.
      llm-providers = {
        file = "${inputs.secrets}/llm.age";
        owner = "root";
        group = "root";
        mode = "0400";
      };

      # All non-provider secrets in env-file format, e.g.:
      #   AUTH_SECRET=...
      #   GATEWAY_API_KEY_HASH_SECRET=...
      #   REDIS_PASSWORD=...
      #   # optional:
      #   # GITHUB_CLIENT_ID=... / GITHUB_CLIENT_SECRET=...
      #   # GOOGLE_CLIENT_ID=... / GOOGLE_CLIENT_SECRET=...
      #   # STRIPE_SECRET_KEY=... / STRIPE_WEBHOOK_SECRET=...
      #   # POSTHOG_KEY=... / POSTHOG_HOST=...
      llmgateway = {
        file = "${inputs.secrets}/llmgateway.age";
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    # ---------------------------------------------------------------- redis
    services.redis.servers.llmgateway = {
      enable = true;
      port = 6379;
      # Loopback + the podman bridge gateway (.1 of our /24) so containers
      # can reach Redis via host.containers.internal.
      bind = "127.0.0.1 10.89.1.1";
      requirePassFile = redisPwFile;
      appendOnly = true;
      settings = {
        protected-mode = "yes";
      };
    };

    # ---------------------------------------------------------------- podman
    virtualisation.podman.enable = true;
    virtualisation.oci-containers.backend = "podman";

    # Create the user-defined network on activation. DNS is enabled per-network;
    # we only force-disabled DNS on the *default* network in detection.nix.
    systemd.services.podman-network-llmgateway = {
      description = "Create podman network for LLMGateway";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.podman}/bin/podman network exists ${networkName} || \
          ${pkgs.podman}/bin/podman network create \
            --subnet=${networkSubnet} \
            --opt isolate=false \
            ${networkName}
      '';
    };

    # Assemble runtime env files from the agenix-decrypted sources:
    #   1) Rewrite llm.age (OPENAI_API_KEY=...) into LLM_*-prefixed names,
    #      so we don't duplicate provider secrets.
    #   2) Extract REDIS_PASSWORD=... from llmgateway.age into a plain
    #      single-line file for services.redis.requirePassFile.
    systemd.services.llmgateway-env = {
      description = "Assemble LLMGateway runtime env files";
      wantedBy = [
        "multi-user.target"
        "redis-llmgateway.service"
      ];
      before = [
        "redis-llmgateway.service"
        "podman-llmgateway-gateway.service"
        "podman-llmgateway-api.service"
        "podman-llmgateway-ui.service"
        "podman-llmgateway-playground.service"
        "podman-llmgateway-docs.service"
        "podman-llmgateway-admin.service"
        "podman-llmgateway-code.service"
      ];
      after = [ "agenix.service" ];
      requires = [ "agenix.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
      };
      script = ''
        set -eu
        mkdir -p ${runtimeDir}
        chmod 0711 ${runtimeDir}

        # --- providers.env: LLM_-prefix every key from llm.age ----------------
        src=${config.age.secrets.llm-providers.path}
        dst=${providerEnvFile}
        : > "$dst"
        chmod 0400 "$dst"
        while IFS= read -r line || [ -n "$line" ]; do
          [ -z "$line" ] && continue
          case "$line" in \#*) continue ;; esac
          key=''${line%%=*}
          val=''${line#*=}
          case "$key" in
            LLM_*) echo "$key=$val" >> "$dst" ;;
            *)     echo "LLM_$key=$val" >> "$dst" ;;
          esac
        done < "$src"

        # --- redis.pw: pull REDIS_PASSWORD value out of llmgateway.age --------
        app=${config.age.secrets.llmgateway.path}
        pw=$(${pkgs.gnugrep}/bin/grep -E '^REDIS_PASSWORD=' "$app" | head -n1 | ${pkgs.coreutils}/bin/cut -d= -f2-)
        if [ -z "$pw" ]; then
          echo "REDIS_PASSWORD missing from llmgateway.age" >&2
          exit 1
        fi
        umask 0377
        printf '%s' "$pw" > ${redisPwFile}
        chown redis-llmgateway:redis-llmgateway ${redisPwFile}
      '';
    };

    # ---------------------------------------------------------- app containers
    virtualisation.oci-containers.containers = {
      llmgateway-api = mkApp {
        name = "api";
        image = "ghcr.io/theopenco/llmgateway-api:${imageTag}";
        port = 4002;
        extraEnv = {
          RUN_MIGRATIONS = "true";
          DATABASE_URL = databaseUrl;
        };
      };

      llmgateway-gateway = mkApp {
        name = "gateway";
        image = "ghcr.io/theopenco/llmgateway-gateway:${imageTag}";
        port = 4001;
        dependsOn = [ "llmgateway-api" ];
        extraEnv = {
          DATABASE_URL = databaseUrl;
          REDIS_HOST = hostGw;
          REDIS_PORT = "6379";
        };
      };

      llmgateway-ui = mkApp {
        name = "ui";
        image = "ghcr.io/theopenco/llmgateway-ui:${imageTag}";
        port = 3002;
        dependsOn = [ "llmgateway-api" ];
      };

      llmgateway-playground = mkApp {
        name = "playground";
        image = "ghcr.io/theopenco/llmgateway-playground:${imageTag}";
        port = 3003;
        dependsOn = [ "llmgateway-api" ];
      };

      llmgateway-docs = mkApp {
        name = "docs";
        image = "ghcr.io/theopenco/llmgateway-docs:${imageTag}";
        port = 3005;
      };

      llmgateway-admin = mkApp {
        name = "admin";
        image = "ghcr.io/theopenco/llmgateway-admin:${imageTag}";
        port = 3006;
        dependsOn = [ "llmgateway-api" ];
      };

      llmgateway-code = mkApp {
        name = "code";
        image = "ghcr.io/theopenco/llmgateway-code:${imageTag}";
        port = 3004;
        dependsOn = [ "llmgateway-api" ];
      };
    };

    # Make every llmgateway container also wait on env assembly, the podman
    # network, Postgres, and Redis. oci-containers names its units podman-<key>.
    systemd.services.podman-llmgateway-api = containerDeps;
    systemd.services.podman-llmgateway-gateway = containerDeps;
    systemd.services.podman-llmgateway-ui = containerDeps;
    systemd.services.podman-llmgateway-playground = containerDeps;
    systemd.services.podman-llmgateway-docs = containerDeps;
    systemd.services.podman-llmgateway-admin = containerDeps;
    systemd.services.podman-llmgateway-code = containerDeps;

    # ---------------------------------------------------------------- caddy
    services.caddy.virtualHosts = {
      "llm.thuis".extraConfig = vhost 3002;
      "llm-api.thuis".extraConfig = vhost 4002;
      "llm-gateway.thuis".extraConfig = vhost 4001;
      "llm-playground.thuis".extraConfig = vhost 3003;
      "llm-docs.thuis".extraConfig = vhost 3005;
      "llm-admin.thuis".extraConfig = vhost 3006;
      "llm-code.thuis".extraConfig = vhost 3004;
    };
  };
}
