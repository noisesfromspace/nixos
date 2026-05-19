{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.maatwerk.browser;
  mkChromeWrappers =
    apps:
    flatten (
      map (
        app:
        let
          script = pkgs.writeShellApplication {
            name = app.name;
            runtimeInputs = [ pkgs.ungoogled-chromium ];
            text = ''
              exec chromium --app="${app.url}" &> /dev/null &
            '';
          };
          desktop = pkgs.makeDesktopItem {
            name = app.name;
            exec = getExe script;
            desktopName = app.name;
            startupWMClass = app.name;
            terminal = false;
          };
        in
        [
          script
          desktop
        ]
      ) apps
    );
in
{
  options.maatwerk.browser = {
    enable = mkEnableOption "Add browsers + config";
  };
  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [ ungoogled-chromium ]
      ++ (mkChromeWrappers [
        {
          name = "teams";
          url = "https://teams.microsoft.com";
        }
        {
          name = "hetzner";
          url = "https://console.hetzner.cloud";
        }
        {
          name = "kvm";
          url = "https://pikvm.machine.thuis/kvm/#";
        }
        {
          name = "nixpkgs";
          url = "https://nixos.org/manual/nixpkgs/unstable/";
        }
      ]);
    programs.librewolf = {
      enable = true;
      package = pkgs.stable.librewolf;
      policies =
        let
          mkExtension =
            {
              id,
              name,
              pinned ? false,
            }:
            {
              "${id}" = {
                default_area = if pinned then "navbar" else "menubar";
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/${name}/latest.xpi";
                installation_mode = "force_installed";
                private_browsing = true;
              };
            };
          # Get ID https://github.com/mkaply/queryamoid/releases/tag/v0.1
          extensionSettings = lib.mergeAttrsList (
            map mkExtension [
              {
                id = "{446900e4-71c2-419f-a6a7-df9c091e268b}";
                name = "bitwarden-password-manager";
                pinned = true;
              }
              {
                id = "@testpilot-containers";
                name = "multi-account-containers";
                pinned = true;
              }
              {
                id = "uBlock0@raymondhill.net";
                name = "ublock-origin";
              }
              {
                id = "transmitter@unrelenting.technology";
                name = "transmitter-for-transmission";
              }
              {
                id = "{d7742d87-e61d-4b78-b8a1-b469842139fa}";
                name = "vimium-ff";
              }
              {
                id = "deArrow@ajay.app";
                name = "dearrow";
              }
              {
                id = "{84601290-bec9-494a-b11c-1baa897a9683}";
                name = "ctrl-number-to-switch-tabs";
              }
              {
                id = "sponsorBlocker@ajay.app";
                name = "sponsorblock";
              }
            ]
          );
        in
        {
          # SecurityDevices.p11-kit-proxy = "${pkgs.p11-kit}/lib/p11-kit-proxy.so";
          ExtensionSettings = extensionSettings;
          PasswordManagerEnabled = false;
          NoDefaultBookmarks = true;
          SkipTermsOfUse = true;
          Containers = {
            Default = [
              {
                name = "Work";
                icon = "briefcase";
                color = "yellow";
              }
            ];
          };
        };
      profiles = {
        default = {
          isDefault = true;
          settings = {
            "webgl.disabled" = false;
            "security.default_personal_cert" = "Select Automatically";
            "privacy.clearOnShutdown.history" = false;
            "privacy.clearOnShutdown.cookies" = false;
            "privacy.clearOnShutdown.sessions" = false;
            "privacy.clearOnShutdown_v2.cookiesAndStorage" = false;
            "browser.fixup.domainsuffixwhitelist.thuis" = true;
            "network.cookie.lifetimePolicy" = 0;
            "network.trr.mode" = 2; # fallback to system
            "network.trr.uri" = "https://dns.thuis/dns-query";
            "network.trr.strict_native_fallback" = false; # Allow native fallback
            "network.trr.retry_on_recoverable_errors" = true; # Retry on recoverable errors
            "network.trr.disable-heuristics" = true; # Disables the canary telemetry detection request "use-application-dns.net" for DOH
            "signon.rememberSignons" = false; # builtin password manager
            "extensions.autoDisableScopes" = 0; # auto-enable installed plugins
            "ui.key.menuAccessKeyFocuses" = false; # don't focus menu on Alt
            "full-screen-api.transition-duration.enter" = "0 0";
            "full-screen-api.transition-duration.leave" = "0 0";
            "accessibility.force_disabled" = true;
            "browser.uidensity" = 1; # compact
            "browser.backspace_action" = 0; # enable backspace back history
            "sidebar.verticalTabs" = true; # we zen browser now
            "sidebar.animation.enabled" = false;
            "sidebar.revamp.round-content-area" = true;
            "sidebar.visibility" = "expand-on-hover";

            # https://bugzilla.mozilla.org/show_bug.cgi?id=1732114
            "privacy.resistFingerprinting" = false;
            "privacy.fingerprintingProtection" = true;
            "privacy.fingerprintingProtection.overrides" = "+AllTargets,-CSSPrefersColorScheme";
          };
          extensions.force = true;
          search = {
            force = true;
            default = "google";
            engines =
              let
                mkEngine =
                  { id, url }:
                  {
                    "${id}" = {
                      urls = [
                        { template = url; }
                      ];
                      definedAliases = [ "!${id}" ];
                    };
                  };
              in
              {
                google.metaData.alias = "!g";
                wikipedia.metaData.alias = "!w";
              }
              // (lib.attrsets.mergeAttrsList (
                map mkEngine [
                  {
                    id = "pkgs";
                    url = "https://search.nixos.org/packages?channel=unstable&query={searchTerms}";
                  }
                  {
                    id = "nixos";
                    url = "https://search.nixos.org/options?channel=unstable&query={searchTerms}";
                  }
                  {
                    id = "hm";
                    url = "https://home-manager-options.extranix.com/?query={searchTerms}&release=master";
                  }
                  {
                    id = "cs";
                    url = "https://github.com/search?type=code&q={searchTerms}";
                  }
                  {
                    id = "gh";
                    url = "https://github.com/search?q={searchTerms}";
                  }
                  {
                    id = "k";
                    url = "https://kagi.com/search?q={searchTerms}";
                  }
                  {
                    id = "vim";
                    url = "https://mattsturgeon.github.io/nixvim/search/?query={searchTerms}";
                  }
                ]
              ));
          };
        };
      };
    };
  };
}
