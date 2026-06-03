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

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/6a471eb3-7d17-4142-b9f0-96f513e60b14";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/80B0-15B0";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "usb_storage"
      "sd_mod"
      "sdhci_pci"
    ];
    kernelModules = [
      "kvm-intel"
      "sch_cake"
    ];
    kernelParams = [
      "console=ttyS0,115200n8"
      "pcie_aspm=off" # fix random interface disconnects?
    ];
    kernel.sysctl = {
      # Enable packet forwarding for both IP protocols.
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = true;

      # Enable strict ARP filtering
      "net.ipv4.conf.all.arp_filter" = 1;
      "net.ipv4.conf.default.arp_filter" = 1;

      # Prevent WebRTC/video call media streams from dying due to NAT timeouts.
      # Defaults (30s/120s) are too short — a lost STUN keepalive (sent every 10-15s)
      # causes the conntrack entry to expire, breaking the media stream.
      "net.netfilter.nf_conntrack_udp_timeout" = 90;
      "net.netfilter.nf_conntrack_udp_timeout_stream" = 300;
    };
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
