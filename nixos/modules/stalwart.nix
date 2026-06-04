{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.hosts.stalwart;

  shoryukenIp = config.global.tailscale_hosts.shoryuken;
  rekkakenIp = config.global.tailscale_hosts.rekkaken;
  stalwartPkg = pkgs.stalwart-custom;
  mxHost = "mx${toString cfg.nodeId}";

  # Certificate paths (copied from Caddy to Stalwart directory)
  certDir = "/var/lib/stalwart/certs";
in
{
  options.hosts.stalwart = {
    enable = lib.mkEnableOption "Stalwart Mail Server with clustering";

    nodeId = lib.mkOption {
      type = lib.types.int;
      description = ''
        Unique node ID for this Stalwart instance in the cluster.
        Must be unique across all nodes.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to open firewall ports for Stalwart services.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy.virtualHosts = {
      "admin-${toString cfg.nodeId}-mail.thuis" = {
        extraConfig = ''
          import headscale
          reverse_proxy http://127.0.0.1:8629
        '';
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        25 # SMTP
        465 # SMTPS
        587 # SMTP Submission
        993 # IMAPS
      ];
    };

    # Agenix secrets - use the stalwart user that NixOS module creates
    age.secrets = {
      stalwart-migadu = {
        file = "${inputs.secrets}/stalwart-migadu.age";
        owner = "stalwart";
        group = "stalwart";
      };
    };

    users.users.stalwart = {
      isSystemUser = true;
      # To access the certs
      home = "/var/lib/stalwart";
      group = "stalwart";
      # For journald logging
      extraGroups = [ "systemd-journal" ];
    };
    users.groups.stalwart = { };

    services.stalwart = {
      enable = true;
      stateVersion = "26.05";
      package = stalwartPkg;

      settings = {
        # Cluster configuration
        cluster = {
          node-id = cfg.nodeId;
          coordinator = "p2p";
        };

        # Stores configuration - use mkForce to override defaults completely
        store = lib.mkForce {
          # Peer-to-peer coordination using Zenoh
          p2p = {
            type = "zenoh";
            config = ''
              {
                mode: "peer",
                scouting: {
                  multicast: {
                    enabled: false
                  },
                  gossip: {
                    enabled: false
                  }
                },
                connect: {
                  endpoints: [
                    "tcp/${if cfg.nodeId == 1 then rekkakenIp else shoryukenIp}:17447"
                  ]
                },
                listen: {
                  endpoints: [
                    "tcp/0.0.0.0:17447"
                  ]
                }
              }
            '';
          };

          # PostgreSQL storage backend
          postgresql = {
            type = "postgresql";
            host = "hadouken.machine.thuis";
            port = 5432;
            database = "stalwart";
            user = "stalwart";
            timeout = "15s";
            pool.max-connections = 10;
          };

          # Garage S3 blob storage
          s3 = {
            type = "s3";
            bucket = "email";
            region = "us-east-1";
            endpoint = "https://garage.thuis";
            access-key = "GKee41184bbe37aed170c62a32";
            timeout = "30s";
          };
        };

        storage = {
          data = "postgresql";
          fts = "postgresql";
          lookup = "postgresql";
          blob = "postgresql";
          directory = "internal";
        };

        directory.internal = {
          type = "internal";
          store = "postgresql";
        };

        server = {
          listener = {
            smtp = {
              bind = [ "[::]:25" ];
              protocol = "smtp";
            };
            smtp-submission = {
              bind = [ "[::]:587" ];
              protocol = "smtp";
              tls.starttls = "require";
              auth.require = true;
            };
            smtps = {
              bind = [ "[::]:465" ];
              protocol = "smtp";
              tls.implicit = true;
            };
            imaps = {
              bind = [ "[::]:993" ];
              protocol = "imap";
              tls.implicit = true;
            };
            http = {
              bind = [ "127.0.0.1:8629" ];
              protocol = "http";
            };
          };

          auto-ban = {
            auth = {
              rate = "10/1h"; # Ban after 10 failed auth attempts per hour
            };
            abuse = {
              rate = "20/1d"; # Ban after 20 abuse attempts per day
            };
            scan = {
              rate = "10/1h"; # Ban aggressive port scanners
              paths = [
                "*.php*"
                "*.cgi*"
                "*/wp-*"
                "*xmlrpc*"
                "*joomla*"
                "*wordpress*"
                "*drupal*"
              ];
            };
          };
        };

        session = {
          rcpt = {
            spf.verify = "relaxed"; # Verify SPF on incoming mail
            dkim.verify = true; # Verify DKIM signatures
            arc.verify = true; # Verify ARC chains
            dmarc.verify = true; # Verify DMARC policy

            # DNSBL/RBL spam blacklist checking
            dnsbl = {
              servers = [
                "zen.spamhaus.org"
                "bl.spamcop.net"
                "b.barracudacentral.org"
              ];
              action = "reject"; # Reject mail from blacklisted IPs
            };
          };
        };

        certificate."${mxHost}-plebian" = {
          cert = "%{file:${certDir}/${mxHost}.plebian.nl.crt}%";
          private-key = "%{file:${certDir}/${mxHost}.plebian.nl.key}%";
        };
        certificate."${mxHost}-boers" = {
          cert = "%{file:${certDir}/${mxHost}.boers.email.crt}%";
          private-key = "%{file:${certDir}/${mxHost}.boers.email.key}%";
        };

        # Queue configuration
        queue = {
          strategy.route = [
            {
              "if" = "is_local_domain('', rcpt_domain)";
              "then" = "'local'";
            }
            { "else" = "'migadu'"; }
          ];

          route = {
            local.type = "local";
            migadu = {
              type = "relay";
              address = "smtp.migadu.com";
              port = 465;
              protocol = "smtp";
              tls.implicit = true;
              auth = {
                username = "martijn@boers.email";
              };
            };
          };

          retry = [
            "2m"
            "5m"
            "10m"
            "15m"
            "30m"
            "1h"
            "2h"
          ];
          expire = "3d";

          # TLS settings for outbound mail (properly nested)
          tls.default = {
            starttls = "require";
            allow-invalid-certs = false;
            dane = "optional"; # Use DANE when available
            mta-sts = "optional"; # Use MTA-STS when available
          };
        };

        # Resolver configuration
        resolver = {
          type = "system";
          public-suffix = [ "file://${pkgs.publicsuffix-list}/share/publicsuffix/public_suffix_list.dat" ];
        };

        # Use pkgs because not built with overrideAttrs
        spam-filter.resource = "file://${pkgs.stalwart-spam-filter}/spam-filter.toml";

        webadmin = {
          resource = "file://${pkgs.stalwart-webadmin}/webadmin.zip";
          path = "/var/cache/stalwart";
        };

      };

    };

    # Ensure Stalwart can connect to Tailscale network and has certificates
    systemd.services.stalwart = {
      after = [
        "tailscaled.service"
        "stalwart-certs.service"
      ];
      requires = [ "tailscaled.service" ];
      wants = [ "stalwart-certs.service" ];
    };

    # Copy Caddy certificates to Stalwart directory with proper permissions
    systemd.services.stalwart-certs = {
      description = "Copy Caddy certificates for Stalwart";
      after = [ "caddy.service" ];
      wants = [ "caddy.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "copy-caddy-certs" ''
          mkdir -p /var/lib/stalwart/certs

          # Find and copy certificates from Caddy
          for domain in mx1.plebian.nl mx1.boers.email mx2.plebian.nl mx2.boers.email; do
            for dir in /var/lib/caddy/.local/share/caddy/certificates/*; do
              if [ -d "$dir/$domain" ]; then
                cp "$dir/$domain/$domain.crt" /var/lib/stalwart/certs/ 2>/dev/null || true
                cp "$dir/$domain/$domain.key" /var/lib/stalwart/certs/ 2>/dev/null || true
              fi
            done
          done

          chown -R stalwart:stalwart /var/lib/stalwart/certs
          chmod 600 /var/lib/stalwart/certs/*.key 2>/dev/null || true
          chmod 644 /var/lib/stalwart/certs/*.crt 2>/dev/null || true
        '';
      };
    };

    systemd.timers.stalwart-certs = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "1h";
      };
    };

    # Ensure directories exist
    systemd.tmpfiles.rules = [
      "d /var/lib/stalwart 0750 stalwart stalwart -"
      "d /var/lib/stalwart/certs 0750 stalwart stalwart -"
      "d /var/cache/stalwart 0755 stalwart stalwart -"
    ];
  };
}
