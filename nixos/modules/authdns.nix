{
  pkgs,
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.hosts.authdns;
  tsigKeyName = "plebs4diamonds";

  rek = {
    ipv4 = config.global.wan_ips.rekkaken;
    ipv6 = config.global.wan_ips.rekkaken_6;
  };
  shor = {
    ipv4 = config.global.wan_ips.shoryuken;
    ipv6 = config.global.wan_ips.shoryuken_6;
  };

  mkStalwartEmail = domain: ''
    ; Mail server A and AAAA records (Internal/Stalwart)
    mx1                   IN      A       ${shor.ipv4}
    mx1                   IN      AAAA    ${shor.ipv6}
    mx2                   IN      A       ${rek.ipv4}
    mx2                   IN      AAAA    ${rek.ipv6}

    ; Mail Exchange (MX) records - Pointing to our Stalwart servers
    @                     IN      MX      10 mx1.${domain}.
    @                     IN      MX      20 mx2.${domain}.
    *                     IN      MX      10 mx1.${domain}.
    *                     IN      MX      20 mx2.${domain}.

    ; Sender Policy Framework (SPF) - Including Migadu
    @                     IN      TXT     "v=spf1 ip4:${shor.ipv4} ip4:${rek.ipv4} ip6:${shor.ipv6} ip6:${rek.ipv6} include:spf.migadu.com -all"

    ; Migadu DKIM Keys (CNAMEs)
    key1._domainkey       IN      CNAME   key1.${domain}._domainkey.migadu.com.
    key2._domainkey       IN      CNAME   key2.${domain}._domainkey.migadu.com.
    key3._domainkey       IN      CNAME   key3.${domain}._domainkey.migadu.com.

    ; DMARC policy (Migadu recommended)
    _dmarc                IN      TXT     "v=DMARC1; p=quarantine;"


    ; MTA-STS (Mail Transfer Agent Strict Transport Security)
    mta-sts               IN      CNAME   @
    _mta-sts              IN      TXT     "v=STSv1; id=1"

    ; Autoconfiguration for email clients
    autoconfig            IN      CNAME   @
    autodiscover          IN      CNAME   @

    ; SRV records for automatic client configuration
    _imaps._tcp           IN      SRV     0 1 993 mx1.${domain}.
    _imaps._tcp           IN      SRV     0 1 993 mx2.${domain}.
    _submission._tcp      IN      SRV     0 1 587 mx1.${domain}.
    _submission._tcp      IN      SRV     0 1 587 mx2.${domain}.
    _submissions._tcp     IN      SRV     0 1 465 mx1.${domain}.
    _submissions._tcp     IN      SRV     0 1 465 mx2.${domain}.
  '';

  allZones = [
    {
      name = "plebian.nl";
      records = ''
        *           IN      A       ${shor.ipv4}
        *           IN      AAAA    ${shor.ipv6}
        @           IN      A       ${shor.ipv4}
        @           IN      AAAA    ${shor.ipv6}
        openpgpkey  IN      TXT     ""

        202604e._domainkey IN TXT   "v=DKIM1; k=ed25519; h=sha256; p=UZFz75x8FlCdqNDP7dCdKAgBzQJvyZ5zlCqGYDsjpAs="
        202604r._domainkey IN TXT   "v=DKIM1; k=rsa; h=sha256; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAx3ARBZrUg6AX12fiGTGKBf0PfqlRzzgVZ/KoScwhhrcuhQryyHM+uHWy5bdnuaqQn5Gg/lqVRJQ+uunU6dN38GrUFGyx4n/iMvqoZFvvCWhWHF+VKQEF3AEw8SK4HlX5sEyv/IUaPGzhmcI/4l1lk9hH10+hQ+Bvywpcb9mSA/w3OpxRLnhHhEu" "30BfizzK/NjntBs98sOTbhTRGx0+4epU9fQyYN8OGh1pW7Sa+RRmroSIpkCuGZf6DB3KBQmYpxQr2m8nQYhtnzPcvg0McQagFNebLebZDKHBjxrK0ANd61VVvJafjHcd2yNjpQYxY+smL/keczQ9rynNj4UMclwIDAQAB"

        ; Migadu Verification
        @                     IN      TXT     "hosted-email-verify=uxeykcyj"


        ; TLSA records (DANE) - Using Let's Encrypt
        ; 
        ; Usage 3 1 1 pins the SPKI (public key) hash of the server certificate
        ; This is stable across renewals as long as the private key is reused
        ;
        ; Usage 3 = DANE-EE (Domain-issued certificate)
        ; Selector 1 = SPKI (Subject Public Key Info) - pins the public key
        ; Matching Type 1 = SHA-256 hash
        ;
        ; After certificates are issued, generate hash with:
        ; openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform DER | openssl sha256
        ;
        ; TODO: Add hash after certificates are generated
        ; _25._tcp            IN      TLSA    3 1 1 <SHA256_HASH_OF_PUBLIC_KEY>
      ''
      + mkStalwartEmail "plebian.nl";
    }
    {
      name = "boers.email";
      records = ''
        *           IN      A       ${shor.ipv4}
        *           IN      AAAA    ${shor.ipv6}
        *.storage   IN      A       ${shor.ipv4}
        *.storage   IN      AAAA    ${shor.ipv6}
        @           IN      A       ${shor.ipv4}
        @           IN      AAAA    ${shor.ipv6}

        headscale   IN      A       ${rek.ipv4}
        headscale   IN      AAAA    ${rek.ipv6}
        derp-map    IN      A       ${rek.ipv4}
        derp-map    IN      AAAA    ${rek.ipv6}
        derp1       IN      A       ${shor.ipv4}
        derp1       IN      AAAA    ${shor.ipv6}
        blog        IN      A       ${shor.ipv4}
        blog        IN      AAAA    ${shor.ipv6}
        derp2       IN      A       ${rek.ipv4}
        derp2       IN      AAAA    ${rek.ipv6}
        ip          IN      A       ${rek.ipv4}
        ip          IN      AAAA    ${rek.ipv6}
         	
        @           IN      TXT     "hosted-email-verify=6livfawy"
        openpgpkey  IN      TXT     ""

        202604e._domainkey IN TXT   "v=DKIM1; k=ed25519; h=sha256; p=aKwl+KIQgsgqwMysx3kVNDbeFYlBiRxAqUHNn7LpaL4="
        202604r._domainkey IN TXT   "v=DKIM1; k=rsa; h=sha256; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzAOjSgbHsF6mRggl7BgkUCx+82wSPhB29TzsEY7vsTMkFw5b77o24QN6/mi7nq546QFIiQGg37R4YeCJSYTYoo26zoNsQXSDOT0idg+547rMSaTM8NVi5wLZjX4NCGkzqkofqjcDPbUk1xYMcxZ5LRp10vOfnljSXF1ftFfacmv6m/fHdaw6eHU" "SByEc+BGl/MXOtL9bMf4n4RJqydSCVysC3JtWyZFdxx/ZoSiFdME/HBVPnmwc5bgRXEF9beDDqxYh7QCw5v0Qb2UJr0A7LH/RlOMnUZBw+yVhjS/nz8pGpiuybOvAdTmaxi5Bsu5FzLJSXIthOY0LxHPJs2AmmQIDAQAB"

        seed._radicle-node._tcp  3600  IN SRV  32767 32767 8776 seed.boers.email.
        seed._radicle-node._tcp  3600  IN TXT  "nid=z6MkhJKKVmjsA2MVrMMqMe2Au7bx8bUVtzWh2A9J3JWTeZAB"
        _radicle-node._tcp       3600  IN PTR  seed._radicle-node._tcp.boers.email.

      ''
      + mkStalwartEmail "boers.email";
    }
    {
      name = "noisesfrom.space";
      records = ''
        @       IN      A       ${shor.ipv4}
        @       IN      AAAA    ${shor.ipv6}
      '';
    }
  ];

  sourceZoneFiles = builtins.listToAttrs (
    map (zoneInfo: {
      name = zoneInfo.name;
      value = pkgs.writeText "${zoneInfo.name}.zone" ''
        $TTL 300
        @ 3600 IN SOA ns1.${zoneInfo.name}. hostmaster.${zoneInfo.name}. (
          1 	; Initial Serial
          7200 	; Refresh
          3600 	; Retry
          86400 ; Expire
          3600 	; Negative Cache TTL
        )
        @   IN  NS  	ns1.${zoneInfo.name}.
        @   IN  NS  	ns2.${zoneInfo.name}.
        ns1 IN  A   	${rek.ipv4}
        ns2 IN  A   	${shor.ipv4}
        ns1 IN  AAAA   	${rek.ipv6}
        ns2 IN  AAAA   	${shor.ipv6}
        ${zoneInfo.records}
      '';
    }) allZones
  );

in
{
  options.hosts.authdns = {
    enable = lib.mkEnableOption "Authoritative DNS for own domains (using Knot)";
    master = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether this server is the master";
    };
  };

  config = lib.mkIf cfg.enable {
    networking = {
      firewall = {
        allowedTCPPorts = [ 53 ];
        allowedUDPPorts = [ 53 ];
      };
    };

    age.secrets.tsigkey = {
      file = "${inputs.secrets}/tsigkey.age";
      owner = "knot";
      group = "knot";
    };

    services.resolved = {
      # Resolved should not bind to port 53
      settings.Resolve.DNSStubListener = "no";
    };

    services.knot = {
      enable = true;
      keyFiles = [ config.age.secrets.tsigkey.path ];
      settings = {
        server = {
          listen = [
            "0.0.0.0@53"
            "::@53"
          ];
        };
        remote = [
          {
            id = "rekkaken";
            address = [ rek.ipv4 ];
            key = tsigKeyName;
          }
          {
            id = "shoryuken";
            address = [ shor.ipv4 ];
            key = tsigKeyName;
          }
        ];
        acl = [
          {
            id = "allow-transfers-from-slave";
            remote = [ "shoryuken" ];
            action = "transfer";
          }
          {
            id = "allow-notifies-from-master";
            remote = [ "rekkaken" ];
            action = "notify";
          }
        ];

        policy = lib.mkIf cfg.master [
          {
            id = "default";
            algorithm = "ECDSAP256SHA256";
          }
        ];

        template = [
          {
            id = "primary-template";
            dnssec-signing = true;
            # https://www.knot-dns.cz/docs/3.3/singlehtml/#example-4
            zonefile-sync = -1;
            zonefile-load = "difference-no-serial";
            journal-content = "all";
            notify = [ "shoryuken" ];
            acl = [ "allow-transfers-from-slave" ];
            serial-policy = "dateserial";
          }
          {
            id = "secondary-template";
            master = [ "rekkaken" ];
            acl = [ "allow-notifies-from-master" ];
          }
        ];

        zone = lib.map (
          zoneInfo:
          if cfg.master then
            {
              domain = zoneInfo.name;
              template = "primary-template";
              file = sourceZoneFiles.${zoneInfo.name};
            }
          else
            {
              domain = zoneInfo.name;
              template = "secondary-template";
            }
        ) allZones;
      };
    };
  };
}
