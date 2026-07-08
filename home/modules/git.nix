{
  osConfig,
  pkgs,
  lib,
  config,
  ...
}:
{
  home.packages = with pkgs; [ radicle-tui ];

  programs.git = {
    enable = true;
    signing = {
      signByDefault = lib.mkDefault true;
      format = "openpgp";
      key = "C1E3 5670 353B 3516 BAA3 51D2 8BA2 F86B 654C 7078";
    };
    ignores = [
      ".ccls-cache"
      "result"
      ".nvim.session"
      ".pi"
      ".devenv*"
    ];
    settings = {
      pull.rebase = "true";
      init.defaultBranch = "main";
      push.autoSetupRemote = "true";
      user.name = "Martijn Boers";
      user.email = "martijn@boers.email";
      diff = {
        algorithm = "histogram";
        indentHeuristic = true;
      };
      alias = {
        patch = "push rad HEAD:refs/patches";
        # Email commits as MIME attachments (e.g., git email-patch HEAD~1..HEAD)
        email-patch = "send-email --attach";
      };
      sendemail = {
        smtpServer = "mx1.boers.email";
        smtpServerPort = 587;
        smtpEncryption = "tls";
        smtpUser = "martijn@boers.email";
        from = "Martijn Boers <martijn@boers.email>";
        smtpAuth = "PLAIN";
        confirm = "auto";
        suppresscc = "self";
      };
      format = {
        # Send patches as MIME attachments rather than raw text in the email body
        attach = "yes";
      };
      "credential \"smtp://martijn%40boers.email@mx1.boers.email:587\"" = {
        helper = "!f() { if [ \"$1\" = \"get\" ]; then echo \"password=$(cat ${config.age.secrets.stalwart-password.path})\"; fi; }; f";
      };
      delta = {
        navigate = true;
        dark = true;
      };
      merge.conflictStyle = "zdiff3";
      merge.tool = "vimdiff";
      rerere.enabled = true;
    };
  };

  # Delta git diff highlighter
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      side-by-side = true;
    };
  };

  services.radicle.node = {
    enable = true;
    lazy.enable = true;
  };

  programs.radicle = {
    enable = true;
    settings = {
      node = {
        alias = osConfig.networking.hostName;
        listen = [ "127.0.0.1:8776" ];
        limits = {
          fetchConcurrency = 5;
          connection.outbound = 32;
        };
        connect = [
          "z6MkhJKKVmjsA2MVrMMqMe2Au7bx8bUVtzWh2A9J3JWTeZAB@seed.boers.email:8776"
          "z6MkhfiyTz7qfggGB45kQRpMfQ1CWuN5sqjAmMrhaYmaARYV@cc.radicle.garden:58776"
        ];
      };
      publicExplorer = "https://git.boers.email/nodes/seed.boers.email/$rid$path";
      preferredSeeds = [ "z6MkhJKKVmjsA2MVrMMqMe2Au7bx8bUVtzWh2A9J3JWTeZAB@seed.boers.email:8776" ];
    };
  };
}
