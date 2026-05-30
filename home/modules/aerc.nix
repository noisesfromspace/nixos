{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.maatwerk.aerc;
in
{
  options.maatwerk.aerc = {
    enable = mkEnableOption "Email client";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.notmuch
      pkgs.notmuch-addrlookup
      pkgs.mq
    ];

    programs.notmuch = {
      enable = true;
      new.tags = [
        "new"
        "inbox"
        "unread"
      ];
      extraConfig = {
        database.path = "${config.home.homeDirectory}/Maildir";
        maildir.synchronize_flags = "true";
      };
    };

    programs.mbsync.enable = true;
    services.mbsync = {
      enable = true;
      frequency = "*:0/2";
      postExec = "${lib.getExe pkgs.notmuch} new";
    };

    programs.aerc = {
      enable = true;
      extraConfig = {
        general.unsafe-accounts-conf = true;
        ui = {
          sort = "-r date";
          timestamp-format = "2006-01-02 15:04";
          threading-enabled = true;
        };
        compose.address-book-cmd = "${lib.getExe pkgs.notmuch-addrlookup} --format=aerc %s";

        filters = {
          "text/plain" = "${lib.getExe pkgs.bat} -fP --style=plain";
          "text/html" = "${lib.getExe pkgs.w3m} -dump -T text/html";
          "application/pdf" = "${pkgs.poppler-utils}/bin/pdftotext - -";
        };
        openers = {
          "text/html" = "xdg-open";
          "application/pdf" = "xdg-open";
        };
      };
    };

    xdg.configFile."aerc/binds.conf".text = ''
      gt = :next-tab<Enter>
      gT = :prev-tab<Enter>
      ? = :help keys<Enter>

      [messages]
      q = :quit<Enter>
      <C-c> = :quit<Enter>
      / = :filter<space>

      k = :prev<Enter>
      j = :next<Enter>

      <C-d> = :next 50%<Enter>
      <C-u> = :prev 50%<Enter>
      gg = :select 0<Enter>
      G = :select -1<Enter>
      V = :mark -V<Enter>
      J = :next-folder<Enter>
      K = :prev-folder<Enter>
      <Space> = :mark -t<Enter>:next<Enter>

      T = :toggle-threads<Enter>
      C = :compose<Enter>

      <Enter> = :view<Enter>
      D = :delete<Enter>
      A = :archive flat<Enter>

      rr = :reply -a<Enter>
      rq = :reply -aq<Enter>
      Rr = :reply<Enter>
      Rq = :reply -q<Enter>

      c = :move<space>
      <Backspace> = :clear<Enter>

      <C-s> = :split<Enter>
      <C-v> = :vsplit<Enter>

      [view]
      / = :toggle-key-passthrough<Enter>/
      q = :close<Enter>
      x = :close<Enter>
      o = :open<Enter>
      S = :save<space>
      D = :delete<Enter>
      A = :archive flat<Enter>

      <C-y> = :copy-link <space>
      <C-l> = :open-link <space>

      f = :forward<Enter>
      rr = :reply -a<Enter>
      rq = :reply -aq<Enter>
      Rr = :reply<Enter>
      Rq = :reply -q<Enter>

      H = :toggle-headers<Enter>
      <C-k> = :prev-part<Enter>
      <C-j> = :next-part<Enter>
      J = :next<Enter>
      K = :prev<Enter>

      [view::passthrough]
      $noinherit = true
      $ex = <C-x>
      <Esc> = :toggle-key-passthrough<Enter>

      [compose]
      $noinherit = true
      $ex = <C-x>
      <tab> = :next-field<Enter>
      <backtab> = :prev-field<Enter>

      [compose::editor]
      $noinherit = true
      $ex = <C-x>

      [compose::review]
      y = :send<Enter>
      n = :abort<Enter>
      s = :sign<Enter>
      q = :choose -o d discard abort -o p postpone postpone<Enter>
      e = :edit<Enter>
      a = :attach<space>
      d = :detach<space>

      [terminal]
      $noinherit = true
      $ex = <C-x>
    '';

    accounts.email.accounts = {
      main =
        let
          address = "martijn@boers.email";
        in
        {
          inherit address;
          primary = true;
          realName = "Martijn Boers";
          userName = address;
          maildir.path = "Stalwart";

          gpg = {
            key = "C1E3 5670 353B 3516 BAA3 51D2 8BA2 F86B 654C 7078";
            signByDefault = true;
          };

          mbsync = {
            enable = true;
            create = "both";
            expunge = "both";
            remove = "both";
            patterns = [ "*" ];
          };

          notmuch.enable = true;

          aerc = {
            enable = true;
            extraAccounts = rec {
              from = address;
              source = "maildir://~/Maildir/Stalwart";
              folders = "Inbox,Sent Items,Signups,Shipping,Bewaren,Werk,Archive,Deleted Items,Junk Mail";
              folders-sort = folders;
              copy-to = "Sent Items";
            };
          };

          imap = {
            host = "mx1.boers.email";
            port = 993;
            tls.enable = true;
          };

          smtp = {
            host = "mx1.boers.email";
            port = 587;
            tls = {
              enable = true;
              useStartTls = true;
            };
          };

          passwordCommand = "cat ${config.age.secrets.stalwart-password.path}";
        };

    };
  };
}
