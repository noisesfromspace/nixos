{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.radicle;
  nativeCiConfig = pkgs.writeText "native-ci.yaml" (
    builtins.toJSON {
      state = "/var/lib/radicle/native-ci/state";
      log = "/var/lib/radicle/native-ci/native-ci.log";
      base_url = "http://ci.thuis";
    }
  );
  customExplorer = pkgs.radicle-explorer.withConfig {
    preferredSeeds = [
      {
        hostname = "seed.boers.email";
        port = 443;
        scheme = "https";
      }
    ];
  };
in
{
  options.hosts.radicle = {
    enable = mkEnableOption "Radicle git node + ci";
  };

  config = mkIf cfg.enable {
    age.secrets.radicle-server.file = "${inputs.secrets}/radicle-server.age";
    age.secrets.github-token = {
      file = "${inputs.secrets}/github-token.age";
      owner = "radicle";
      group = "radicle";
    };

    users.users.caddy.extraGroups = [ "radicle" ];

    systemd.services.radicle-ci-broker = {
      serviceConfig = {
        EnvironmentFile = config.age.secrets.github-token.path;
        LoadCredential = "pgp-public:${inputs.secrets}/keys/pgp.asc";
      };
      path = with pkgs; [
        git
        bash
        coreutils
        curl
        gnupg
      ];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/radicle 0750 radicle radicle -"
      "d /var/lib/radicle/ci-reports 0750 radicle radicle -"
      "d /var/lib/radicle/native-ci 0750 radicle radicle -"
      "d /var/lib/radicle/native-ci/state 0750 radicle radicle -"
      "f /var/lib/radicle/native-ci/native-ci.log 0640 radicle radicle -"
      "a+ /var/lib/radicle/native-ci/state - - - - d:g:radicle:rx,g:radicle:rx"
    ];

    services.caddy.virtualHosts = {
      "seed.boers.email" = {
        extraConfig = ''
          reverse_proxy ${config.services.radicle.httpd.listenAddress}:${toString config.services.radicle.httpd.listenPort}
        '';
      };
      "git.boers.email" = {
        extraConfig = ''
          root * ${customExplorer}
          file_server
          try_files {path} /index.html
        '';
      };
      "ci.thuis" = {
        extraConfig = ''
          import headscale

          @runs path_regexp run ^/[a-f0-9-]{36}/.*$
          handle @runs {
            root * /var/lib/radicle/native-ci/state
            file_server
          }

          handle {
            root * /var/lib/radicle/ci-reports
            file_server browse
          }
        '';
      };
    };
    services.radicle = {
      enable = true;
      privateKey = config.age.secrets.radicle-server.path;
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICpIiSK+rRAp4HPvWrjy2iUluPcInEsHAqJTN5FIOCFc radicle";

      ci = {
        # https://app.radicle.xyz/nodes/radicle.liw.fi/rad:zwTxygwuz5LDGBq255RA2CbNGrz8/tree/doc/userguide.md
        broker = {
          enable = true;
          settings = {
            report_dir = "/var/lib/radicle/ci-reports";
            adapters.native = {
              command = "${pkgs.radicle-native-ci}/bin/radicle-native-ci";
              env = {
                RAD_HOME = "/var/lib/radicle";
                RADICLE_NATIVE_CI = "${nativeCiConfig}";
              };
            };
            triggers = [
              {
                adapter = "native";
                filters = [
                  {
                    And = [
                      { HasFile = ".radicle/native.yaml"; }
                      {
                        Or = [
                          { Node = "z6MkqW1hUP7eyCVEcNm3DyT6NPYAdJuGunkNW5EcB4fY5fEN"; } # donk
                          { Node = "z6MkrST9cLyV8NmWorWfXnfeRpYmRcmbKifMe9oiKaFJpqrw"; } # nurma
                          { Node = "z6MkkE5buQW9vLSqcmqUSTurMLDvjN82qwTDUoiG4T7NWnkc"; } # paddy
                        ];
                      }
                      {
                        Or = [
                          "DefaultBranch"
                          "PatchCreated"
                          "PatchUpdated"
                        ];
                      }
                    ];
                  }
                ];
              }
            ];
          };
        };
      };

      settings = {
        web = {
          avatarUrl = "https://random.storage.boers.email/icon.png";
          description = "Martijn's Radicle repositories";
          pinned = {
            repositories = [
              "rad:z2Jkf9zxGPxEhCfGLpgRAcHRj8x2n" # Nix
              "rad:z3bTedCQLQRkCdAmKKZTMSBimNp4J" # boers.email
              "rad:z2r9euHZW161kfQNxdF4apHddD3mm" # mq
              "rad:z2AdUML1AaZmUVidUJ4vwQDJhmvKg" # unaware
              "rad:z24gQBBitUHvTz4y8t4JrCNCPrfpG" # gettit
              "rad:z3idaVuBJSG4LUD3zbP2PoXfry3xX" # touchup.nvim
              "rad:zb1FuXow3wJemDDPFWGFa49rNA4z" # gpg-poc-T8044
              "rad:z2dyxUsTyMyQeuBbKPgkLRspWfNpa" # overlap
            ];
          };
        };
        node = {
          alias = config.networking.hostName;
          externalAddresses = [ "seed.boers.email:8776" ];
          seedingPolicy.default = "block";
        };
      };
      node.openFirewall = true;

      httpd = {
        enable = true;
        listenPort = 8027;
      };
    };
  };
}
