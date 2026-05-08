{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.maatwerk.nixvim;
  helpers = config.lib.nixvim;
in
{
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      (pkgs.mdformat.withPlugins (p: [
        p.mdformat-beautysh
        p.mdformat-footnote
        p.mdformat-frontmatter
        p.mdformat-gfm
      ]))
      golangci-lint
      shellharden
      shellcheck
      prettier
      rustfmt
      yamlfmt
      eslint
      tflint
      stylua
      nixfmt
      clang
      shfmt
      black
      biome
      ruff
      jq
    ];

    programs.nixvim = {
      plugins = {
        conform-nvim = {
          enable = true;
          settings = {
            stop_after_first = true;
            formatters_by_ft = {
              css = [ "biome" ];
              html = [ "prettier" ];
              htmldjango = [ "prettier" ];
              javascript = [ "biome" ];
              javascriptreact = [ "biome" ];
              json = [ "jq" ];
              lua = [ "stylua" ];
              nix = [ "nixfmt" ];
              python = [ "black" ];
              typescript = [ "biome" ];
              typescriptreact = [ "biome" ];
              yaml = [ "yamlfmt" ];
              zig = [ "zig" ];
              rust = [ "rustfmt" ];
              markdown = [ "mdformat" ];
              go = [ "go" ];
              c = [ "clang-format" ];
              cpp = [ "clang-format" ];
              bash = [
                "shellcheck"
                "shellharden"
                "shfmt"
              ];
              "_" = [
                "trim_whitespace"
                "trim_newlines"
              ];
            };
          };
        }; # formatters

        lint = {
          enable = true;
          lintersByFt = {
            nix = [ "nix" ];
            python = [ "ruff" ];
            javascript = [ "eslint" ];
            go = [ "golangcilint" ];
            terraform = [ "tflint" ];
          };
        }; # code style linting

        treesitter = {
          enable = true;
          settings = {
            highlight.enable = true;
            indent.enable = true;
          };
        }; # syntax highlighting

        lsp = {
          enable = true;
          keymaps = {
            lspBuf = {
              K = "hover";
              gD = "references";
              gd = "definition";
              gr = "rename";
              ga = "code_action";
            };
          };
          servers = {
            bashls.enable = true;
            nixd.enable = true;
            html.enable = true;
            jsonls.enable = true;
            lua_ls.enable = true;
            terraformls.enable = true;
            pyright.enable = true;
            gopls.enable = true;
            ccls.enable = true;
            zls.enable = true;
            ruby_lsp.enable = true;
            jdtls.enable = true; # Java (nice naming)
            vtsls.enable = true; # JavaScript (nice naming)
            yamlls.enable = true;
            markdown_oxide = {
              enable = true;
              package = pkgs.markdown-oxide.overrideAttrs (
                old:
                let
                  newSrc = pkgs.fetchFromGitHub {
                    owner = "noisesfromspace";
                    repo = "markdown-oxide";
                    rev = "7548d8c4078f12b3a7d7f058d69b30403e278297";
                    hash = "sha256-A2FhCSxWDaOYPH9Gkk7Lc0oLxbtUx9cEX7uDB/kJUGE=";
                  };
                in
                {
                  src = newSrc;
                  cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
                    src = newSrc;
                    hash = "sha256-Ts+nuQkeZYvp1p8A0mv9SC83Ft/MjQQZG9eOlBFCkIg=";
                  };
                }
              );
            };
            docker_compose_language_service.enable = true;
            rust_analyzer = {
              enable = true;
              installCargo = true;
              installRustc = true;
            };
          };
        }; # language servers

        navic = {
          enable = true;
          settings = {
            lsp.auto_attach = true;
            depth_limit = 3;
            separator = " › ";
            highlight = false;
            safe_output = true;
          };
        }; # code context in statusline
      };

      keymaps = [
        {
          action = helpers.mkRaw ''
            function() require("conform").format({ 
              lsp_fallback = true,
              async = false,
              timeout_ms = 500, 
            }) end '';
          mode = [
            "v"
            "n"
          ];
          key = "=";
          options.desc = "Remap = when conform";
        }
      ];
    };
  };
}
