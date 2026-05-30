{
  config,
  lib,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.adguard;
in
{
  options.hosts.adguard = {
    enable = mkEnableOption "Adguard say no to ads";
  };

  config = mkIf cfg.enable {
    services.caddy.virtualHosts."dns.thuis".extraConfig = ''
      import headscale
      handle @internal {
       reverse_proxy http://localhost:${toString config.services.adguardhome.port}
       handle_path /dns-query/* {
          reverse_proxy http://127.0.0.1:${toString config.services.adguardhome.settings.tls.port_dns_over_tls}
       }
      }
      respond 403
    '';

    age.secrets.adguard.file = "${inputs.secrets}/adguard.age";

    services.resolved = {
      # Resolved should not bind to port 53
      settings.Resolve.DNSStubListener = "no";
    };

    systemd.services = {
      adguardhome = {
        after = [ "tailscaled.service" ];
        requires = [ "tailscaled.service" ];
      };
    };

    services.adguardhome = {
      enable = true;
      mutableSettings = false;
      allowDHCP = false;
      host = "127.0.0.1"; # for webgui but using caddy reverse proxy
      port = 3043;

      settings = {
        dns = {
          ratelimit = 0;
          bind_hosts = [ "0.0.0.0" ];
          upstream_dns = [
            "https://dns10.quad9.net/dns-query"
            "https://dns.freedom.nl/dns-query"
          ];
          allowed_clients = [
            "100.64.0.0/10" # tailscale
            "10.10.0.0/23" # lan
            "10.20.0.0/24" # wifi
            "10.30.0.0/24" # opt1
          ];
          use_http3_upstreams = true;
          upstream_mode = "parallel";
          bootstrap_dns = [
            "9.9.9.9"
            "208.67.222.222"
          ];
          protection_enabled = true;
          enable_dnssec = true;
          blocked_hosts = [
            "version.bind"
            "id.server"
            "hostname.bind"
          ];
          cache_ttl_min = 1 * 60 * 60; # 1 hour
          cache_ttl_max = 24 * 60 * 60; # 24 hours
          # Responds from expired cache while refreshing in the background.
          cache_optimistic = true;

        };
        tls = {
          enabled = false;
          server_name = "dns.thuis";
          port_https = 0; # 0 is disabled
          port_dns_over_tls = 853;
          force_https = false;
          allow_unencrypted_doh = true; # caddy does this
        };
        filters = [
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt";
            name = "github.com/FadeMind/hosts.extras";
          }
          {
            enable = true;
            url = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/pro.plus.txt";
            name = "github.com/hagezi/dns-blocklists";
          }
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts";
            name = "github.com/FadeMind/hosts.extras";
          }
          {
            enabled = true;
            url = "https://v.firebog.net/hosts/static/w3kbl.txt";
            name = "firebog.net/about";
          }
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/matomo-org/referrer-spam-blacklist/master/spammers.txt";
            name = "github.com/matomo-org/referrer-spam-list";
          }
          {
            enabled = true;
            url = "https://adaway.org/hosts.txt";
            name = "adaway.org";
          }
          {
            enabled = true;
            url = "https://someonewhocares.org/hosts/zero/hosts";
            name = "someonewhocares.org/";
          }
          {
            enabled = true;
            url = "https://v.firebog.net/hosts/Easyprivacy.txt";
            name = "firebog.net/";
          }
          {
            enabled = true;
            url = "https://easylist.to/easylist/easylist.txt";
            name = "easylist";
          }
          {
            enabled = true;
            url = "https://v.firebog.net/hosts/Prigent-Ads.txt";
            name = "firebog.net/";
          }
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts";
            name = "github.com/FadeMind/hosts.extras";
          }
          {
            enabled = true;
            url = "https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt";
            name = "frogeye.fr";
          }
          {
            enabled = true;
            url = "https://v.firebog.net/hosts/AdguardDNS.txt";
            name = "AdGuardDNS";
          }
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt";
            name = "github.com/DandelionSprout/adfilt";
          }
          {
            enabled = true;
            url = "https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt";
            name = "disconnect.me/";
          }
          {
            enabled = true;
            url = "https://v.firebog.net/hosts/Prigent-Crypto.txt";
            name = "firebog.net/";
          }
          {
            enabled = true;
            url = "https://phishing.army/download/phishing_army_blocklist_extended.txt";
            name = "phishing.army";
          }
          {
            enabled = true;
            url = "https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt";
            name = "github.com/Ultimate-Hosts-Blacklist/quidsup_notrack_trackers";
          }
        ];
        theme = "auto";
        users = [
          {
            name = "admin";
            password = "$2a$12$2.LYNDcUmLA/14My1r592.lNs32aWsF7q6g6RwdGG0BPF.cbyde/W";
          }
        ];
      };
    };
  };
}
