{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.maatwerk.khal;
in
{
  options.maatwerk.khal = {
    enable = mkEnableOption "Khal & Khard";
  };

  config = mkIf cfg.enable {
    age.secrets.radicale-client = {
      file = "${inputs.secrets}/radicale-client.age";
    };

    programs.todoman = {
      enable = true;
      extraConfig = ''
        default_list = "martijn"
      '';
    };

    programs.vdirsyncer.enable = true;
    services.vdirsyncer = {
      enable = true;
      frequency = "*:0/15";
    };

    programs.khal = {
      enable = true;
      settings = {
        default = {
          default_calendar = "martijn";
          timedelta = "1h";
        };
        keybindings = {
          external_edit = "ctrl o";
          new = "c";
        };
      };
    };

    accounts.calendar = {
      basePath = ".local/share/calendars";
      accounts."martijn" = {
        vdirsyncer.enable = true;
        khal = {
          enable = true;
          type = "calendar";
          readOnly = false;
        };
        local = {
          type = "filesystem";
          fileExt = ".ics";
        };
        remote = {
          type = "caldav";
          url = "https://cal.thuis/martijn/e4794380-2fa2-e122-8090-2e0d71c628a8/";
          userName = "martijn";
          passwordCommand = [
            "sh"
            "-c"
            "${pkgs.coreutils}/bin/cat ${config.age.secrets.radicale-client.path}"
          ];
        };
      };
    };

    programs.khard = {
      enable = true;
      package = pkgs.stable.khard;
      settings = {
        "general" = {
          default_action = "list";
          editor = "nvim";
          merge_editor = "vimdiff";
        };
      };
    };

    accounts.contact.basePath = ".local/share/contacts";
    accounts.contact.accounts."contacts" = {
      vdirsyncer.enable = true;
      khard.enable = true;

      local = {
        type = "filesystem";
        fileExt = ".vcf";
      };

      remote = {
        type = "carddav";
        url = "https://cal.thuis/martijn/743cfb06-3a31-5222-4e8b-907dfc5936c9/";
        userName = "martijn";
        passwordCommand = [
          "sh"
          "-c"
          "cat ${config.age.secrets.radicale-client.path}"
        ];
      };
    };

  };
}
