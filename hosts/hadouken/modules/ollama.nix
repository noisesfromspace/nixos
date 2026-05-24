{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.hosts.ollama;
  ollamaPort = 11434;
in
{
  options.hosts.ollama = {
    enable = mkEnableOption "Shared Ollama instance";
  };

  config = mkIf cfg.enable {
    services.caddy.virtualHosts."ollama.thuis" = {
      extraConfig = ''
        import headscale
        handle @internal {
          reverse_proxy http://localhost:${toString ollamaPort}
        }
        respond 403
      '';
    };

    services.ollama = {
      enable = true;
      host = "127.0.0.1";
      port = ollamaPort;
      loadModels = [
        "llama3.1:8b"
        "qwen2.5-coder:7b"
      ];
    };
  };
}
