{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.hosts.openssh;
in
{
  options.hosts.openssh = {
    enable = mkEnableOption "Enable OpenSSH server";
    allowUsers = mkOption {
      type = types.listOf types.str;
      default = [ "martijn@100.64.0.0/10" ];
      description = "Set IP restrictions";
    };
  };

  config = mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      maxretry = 5;
      bantime = "1h";
      bantime-increment = {
        enable = true; # Enable increment of bantime after each violation
        multipliers = "1 2 4 8 16 32 64 128 256";
        maxtime = "168h"; # Do not ban for more than 1 week
        overalljails = true; # Calculate the bantime based on all the violations
      };
    };

    # https://ryanseipp.com/posts/nixos-secure-ssh/
    # https://saylesss88.github.io/nix/hardening_NixOS.html#openssh-server
    services.openssh = {
      enable = true;
      ports = [ 22 ];
      settings = {
        PermitRootLogin = "no";
        X11Forwarding = false;
        KbdInteractiveAuthentication = false;
        PermitEmptyPasswords = false;
        PasswordAuthentication = false;
        MaxAuthTries = 5;
        MaxSessions = 4;
        UseDns = false;
        KexAlgorithms = [
          # Post-Quantum: https://www.openssh.org/pq.html
          "mlkem768x25519-sha256"
          "sntrup761x25519-sha512"
          "curve25519-sha256@libssh.org"
          "ecdh-sha2-nistp521"
          "ecdh-sha2-nistp384"
          "ecdh-sha2-nistp256"
          "diffie-hellman-group-exchange-sha256"
        ];
        Ciphers = [
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
          # stream cipher alternative to aes256, proven to be resilient
          # Very fast on basically anything
          "chacha20-poly1305@openssh.com"
          # industry standard, fast if you have AES-NI hardware
          "aes256-ctr"
          "aes192-ctr"
          "aes128-ctr"
        ];
        Macs = [
          # Combines the SHA-512 hash func with a secret key to create a MAC
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256-etm@openssh.com"
          "umac-128-etm@openssh.com"
          "hmac-sha2-512"
          "hmac-sha2-256"
          "umac-128@openssh.com"
        ];
        ListenAddress = "0.0.0.0";
        AllowUsers = cfg.allowUsers;
        LogLevel = "VERBOSE";
      };
      openFirewall = true;
      hostKeys = [
        {
          path = "/home/martijn/.ssh/id_ed25519";
          type = "ed25519";
        }
      ];
    };
  };
}
