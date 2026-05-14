{
  osConfig,
  pkgs,
  lib,
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
        connect = [ "z6MkhJKKVmjsA2MVrMMqMe2Au7bx8bUVtzWh2A9J3JWTeZAB@seed.boers.email:8776" ];
      };
      publicExplorer = "https://git.boers.email/nodes/seed.boers.email/$rid$path";
      preferredSeeds = [ "z6MkhJKKVmjsA2MVrMMqMe2Au7bx8bUVtzWh2A9J3JWTeZAB@seed.boers.email:8776" ];
    };
  };
}
