{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "usbhid"
  ];
  boot.loader.raspberry-pi.bootloader = "kernel";

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [
      "noatime"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=1min"
    ];
  };

  systemd.network.networks."10-end0" = {
    matchConfig.Name = "end0";
    networkConfig = {
      DHCP = "no"; # no ipv4 dhcp
      IPv6AcceptRA = true;
    };
    address = [
      "${config.global.lan_ips.tenshin}/24"
    ];
    routes = [
      { Gateway = "10.10.0.1"; }
    ];
    linkConfig.RequiredForOnline = "routable";
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
