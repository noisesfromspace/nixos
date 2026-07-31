{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hosts.rspamd;
in
{
  options.hosts.rspamd = {
    enable = lib.mkEnableOption "Rspamd spam filter with AI-powered GPT plugin";
  };

  config = lib.mkIf cfg.enable {
    services.redis.servers.rspamd = {
      enable = true;
      port = 6379;
      bind = "127.0.0.1";
    };

    services.rspamd = {
      enable = true;

      workers = {
        # Normal worker: scanning engine, rspamc connects here for testing
        normal = {};

        # Controller worker: web UI + HTTP API on localhost
        controller = {
          bindSockets = [{
            socket = "127.0.0.1:11334";
          }];
        };

        # Proxy worker: milter endpoint Stalwart nodes connect to over tailscale
        rspamd_proxy = {
          enable = true;
          bindSockets = [{
            socket = "0.0.0.0:11332";
          }];
          extraConfig = ''
            milter = yes;
            upstream "local" {
              default = yes;
              self_scan = yes;
            }
          '';
        };

      };

      locals = {
        # GPT plugin: query local Ollama for ambiguous messages (score 3-8)
        # NOTE: no gpt {} wrapper - local.d/<name>.conf is implicitly inside
        # the <name> section; wrapping produces gpt { gpt {} } and the module
        # stays disabled
        "gpt.conf".text = ''
          enabled = true;
          type = "ollama";
          url = "http://127.0.0.1:11434/api/chat"; # full endpoint; plugin POSTs verbatim
          model = "llama3.2:3b";
          timeout = 15; 
          autolearn = true;
          reason_header = "X-GPT-Reason";

          symbols_to_except {
            BAYES_SPAM = 0.9;
            WHITELIST_SPF = -1;
          }

          # Only call GPT when the message is borderline (score 3-8)
          # ~80% of mail skips the LLM entirely via this gate.
          # Contract: must return (allowed, content, sel_part) - see
          # default_condition in gpt.lua; returning only a boolean silently
          # skips GPT ("no content to send").
          condition = <<EOLUA
return function(task)
  local result = task:get_metric_result()
  local score = result and result.score or 0
  if score < 3 or score > 8 then
    return false, 'score ' .. score .. ' outside 3-8 gate'
  end
  local lua_mime = require "lua_mime"
  local llm_common = require "llm_common"
  local sel_part = lua_mime.get_displayed_text_part(task, 10)
  if not sel_part then
    return false, 'no text part found'
  end
  local input_tbl = llm_common.build_llm_input(task, {
    max_tokens = 1000,
    min_words = 10,
  })
  if not input_tbl then
    return false, 'no content to send'
  end
  return true, input_tbl, sel_part
end
EOLUA
        '';

        # Task timeout must exceed GPT timeout (15s) or the task dies at the
        # default 8s mid-inference (ollama logs 499 client disconnect)
        "options.inc".text = ''
          task_timeout = 25s;
        '';

        # Redis on localhost: cache GPT responses across Stalwart nodes
        "redis.conf".text = ''
          servers = "127.0.0.1:6379";
        '';

        # Add headers for Stalwart Sieve spam filtering
        "milter_headers.conf".text = ''
          use = ["x-spam-flag", "x-spam-status", "authentication-results"];
        '';

        # Tune scoring: reject at 15, flag suspicious at 5, no greylisting
        "actions.conf".text = ''
          reject = 15;
          add_header = 5;
          greylist = null;
        '';
      };
    };
  };
}
