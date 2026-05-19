{ ... }:
{
  networking = {
    hostName = "hadouken";
    hostId = "1b936a2a";
  };

  imports = [
    ./modules/monitoring.nix
    ./modules/detection.nix
    ./modules/mastodon.nix
    ./modules/paperless.nix
    ./modules/microbin.nix
    ./modules/calendar.nix
    ./modules/database.nix
    ./modules/garage.nix
    ./modules/bincache.nix
    ./modules/storage.nix
    ./modules/matrix.nix
    ./modules/immich.nix
    ./modules/shares.nix
    ./modules/caddy.nix
    ./modules/atuin.nix
    ./modules/media.nix
  ];

  hosts.shares.enable = true;
  hosts.caddy.enable = true;
  hosts.media.enable = true;
  hosts.tailscale.enable = true;
  hosts.monitoring.enable = true;
  hosts.matrix.enable = true;
  hosts.mastodon.enable = true;
  hosts.microbin.enable = true;
  hosts.changedetection.enable = true;
  hosts.immich.enable = true;
  hosts.prometheus.enable = true;
  hosts.calendar.enable = true;
  hosts.database.enable = true;
  hosts.garage.enable = true;
  hosts.atuin.enable = true;
  hosts.paperless.enable = true;
  hosts.bincache.enable = true;
  hosts.nymvpn.enable = true;

  users = {
    groups.notes.members = [ "caddy" ];
  };

  systemd.services.loki = {
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    serviceConfig.RestartSec = 10;
  };

  hosts.borg = {
    enable = true;
    repository = "ssh://gak69wyz@gak69wyz.repo.borgbase.com/./repo";
    paths = [ "/mnt/zwembad/app" ];
  };

  # Migrating
  nixpkgs.config.permittedInsecurePackages = [
    "minio-2025-10-15T17-29-55Z"
  ];

  # Heat management intel cpu
  services.thermald.enable = true;

  hosts.openssh = {
    enable = true;
    allowUsers = [
      "*@100.64.0.0/10"
      "*@10.30.0.0/24"
    ];
  };

  # Server defaults
  hosts.server.enable = true;

  boot = {
    supportedFilesystems = [ "zfs" ];
    zfs = {
      forceImportRoot = false;
      extraPools = [
        "zwembad"
        "zolder"
      ];
    };

    # Silent Boot
    # https://wiki.archlinux.org/title/Silent_boot
    kernelParams = [
      "quiet"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
    consoleLogLevel = 0;
    initrd.verbose = false;
  };
}
