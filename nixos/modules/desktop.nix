{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.desktop;
in
{

  options.hosts.desktop = {
    enable = mkEnableOption "Base desktop";
  };

  config = mkIf cfg.enable {
    environment.sessionVariables = {
      TERM = "xterm-ghostty";
      BROWSER = "librewolf";
      DEFAULT_BROWSER = "librewolf";
    };

    environment.systemPackages = with pkgs; [
      veracrypt
    ];

    users.users.martijn.extraGroups = [
      "wireshark"
      "tor" # read authcookie
    ];

    age.secrets = {
      password-laptop.file = lib.mkDefault "${inputs.secrets}/password-laptop.age";
    };

    hosts.nymvpn = {
      enable = false;
      autoConnect = false;
    };

    # DBus power information provider
    services.upower.enable = true;

    # System-wide hardware accelerometer sensor proxy for auto-rotation
    hardware.sensor.iio.enable = true;

    programs.wireshark = {
      enable = true;
      usbmon.enable = true;
      dumpcap.enable = true;
      package = pkgs.stable.wireshark;
    };

    nixpkgs = {
      config = {
        permittedInsecurePackages = [
          "libxml2-2.13.8" # CVE-2025-6021
          "libsoup-2.74.3" # gnome cves
          "python3.12-ecdsa-0.19.1" # electrum
        ];
      };
    };
    nix = {
      settings = {
        substituters = [
          "https://devenv.cachix.org"
          "https://cache.numtide.com"
          "https://noctalia.cachix.org"
        ];
        trusted-public-keys = [
          "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
          "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        ];
      };
    };

    services.tor = {
      enable = true;
      client.enable = true;
      # controlPort = 9051;
      # settings = {
      #   CookieAuthentication = true;
      #   CookieAuthFileGroupReadable = true;
      # };
    };

    virtualisation = {
      containers.enable = true;
      podman = {
        enable = true;
        dockerCompat = true;
        # Required for containers under podman-compose to be able to talk to each other.
        defaultNetwork.settings.dns_enabled = true;
      };
    };

    boot.supportedFilesystems = [ "nfs" ];

    fileSystems =
      let
        mkNfsShare = name: {
          "/mnt/${name}" = {
            device = "hadouken.machine.thuis:/${name}";
            fsType = "nfs";
            options = [
              # "rsize=1048576" # bigger read+write sizes
              # "wsize=1048576" # good for bigger files
              "rsize=32768" # Use smaller read/write sizes
              "wsize=32768" # Better performance over high-latency networks.
              "noatime" # Don't update file access times on read
              "tcp"
              "soft" # timeout instead of freezing
              "x-systemd.automount" # lazymount
              "_netdev" # this makes the .mount unit require network-online.target
              "x-systemd.requires=tailscaled.service"
              "x-systemd.after=tailscaled.service"
            ];
          };
        };
      in
      lib.attrsets.mergeAttrsList (
        map mkNfsShare [
          "music"
          "share"
        ]
      );

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };
      bluetooth = {
        enable = true;
        powerOnBoot = true;
      };
      keyboard.qmk.enable = true; # Access QMK without sudo
    };

    programs.dconf.enable = true; # used for stylix

    # Enable sound with pipewire.
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
