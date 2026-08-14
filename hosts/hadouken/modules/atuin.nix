{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.atuin;
  aiPort = 8080;
  aiModel = "anthropic/claude-haiku-4.5";
in
{
  options.hosts.atuin = {
    enable = mkEnableOption "Synchronize zsh history files and self-host Atuin AI";
  };

  config = mkIf cfg.enable {
    # ---------- Sync server ----------
    services.caddy.virtualHosts."atuin.thuis".extraConfig = ''
      import headscale
      handle @internal {
         reverse_proxy http://localhost:${toString config.services.atuin.port}
      }
      respond 403
    '';

    services.postgresqlBackup.databases = [ "atuin" ];

    services.atuin = {
      enable = true;
      openRegistration = false;
      port = 8965;
    };

    # ---------- AI server (self-hosted, OpenRouter-backed) ----------
    environment.etc."atuin-ai/config.toml".text = ''
      port = ${toString aiPort}
      endpoint = "https://openrouter.ai/api/v1"
      default_model = "claude-haiku"

      [api_key]
      env = "OPENROUTER_API_KEY"

      [request.body]
      stream_options = { include_usage = true }

      [[models]]
      alias = "claude-haiku"
      name = "Claude Haiku 4.5"
      description = "Small Anthropic model via OpenRouter"
      model = "${aiModel}"
    '';

    systemd.services.atuin-ai-server = {
      description = "Atuin AI server (OpenRouter-backed)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        CHAT_CONFIG = "/etc/atuin-ai/config.toml";
        # The release writes its runtime sys.config here; default ($release/tmp)
        # is read-only in the Nix store.
        RELEASE_TMP = "/var/lib/atuin-ai-server/tmp";
        LANG = "C.UTF-8";
      };

      serviceConfig = {
        ExecStart = "${pkgs.atuin-ai-server}/bin/atuin_ai_server start";
        Restart = "on-failure";
        RestartSec = 5;
        User = "atuin-ai-server";
        Group = "atuin-ai-server";
        StateDirectory = "atuin-ai-server";
        EnvironmentFile = config.age.secrets.atuin-ai-openrouter.path;

        # Hardening (mirrors the official Atuin systemd unit)
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        PrivateTmp = true;
        PrivateDevices = true;
        LockPersonality = true;
        RestrictSUIDSGID = true;
      };
    };

    users.users.atuin-ai-server = {
      isSystemUser = true;
      group = "atuin-ai-server";
    };
    users.groups.atuin-ai-server = { };

    # Reuses the same encrypted env file as the pi coding agent; only
    # OPENROUTER_API_KEY is read by the AI server.
    age.secrets.atuin-ai-openrouter = {
      file = "${inputs.secrets}/worker-pi-auth.age";
      owner = "atuin-ai-server";
    };

    # Tailscale-only access, same pattern as atuin.thuis / ollama.thuis.
    services.caddy.virtualHosts."atuin-ai.thuis".extraConfig = ''
      import headscale
      handle @internal {
        reverse_proxy http://127.0.0.1:${toString aiPort}
      }
      respond 403
    '';
  };
}
