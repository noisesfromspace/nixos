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
    device = "/dev/disk/by-uuid/94423d1c-1ff2-41cb-9c23-2d8444015324";
    fsType = "ext4";
  };

  boot = {
    kernelModules = [ "kvm-amd" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    initrd = {
      kernelModules = [ "amdgpu" ];
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];

      luks.devices.root = {
        device = "/dev/disk/by-uuid/68b29e46-0399-4b6c-bcaa-c29cdf47330e";
        crypttabExtraOpts = [ "fido2-device=auto" ];
      };

      systemd.enable = true;
    };
  };

  systemd.network.networks = {
    "50-dhcp" = {
      matchConfig.Name = "enp11s0";
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = true;
      };
      address = [
        "10.30.0.2/24"
      ];
      routes = [
        { Gateway = "10.30.0.1"; }
      ];
      linkConfig.RequiredForOnline = "routable";
    };
    "50-wireless" = {
      matchConfig.Name = "wlan0";
      dhcpV4Config.UseDNS = false;
      dhcpV6Config.UseDNS = false;
      linkConfig.RequiredForOnline = "no";
      networkConfig = {
        DHCP = "yes";
        IgnoreCarrierLoss = "3s";
      };
    };
  };

  networking.wireless.iwd = {
    enable = true;
    settings = {
      IPv6.Enabled = true;
      # https://man.archlinux.org/man/iwd.network.5#SETTINGS
      Settings = {
        AutoConnect = true;
        Hidden = true; # show hidden
        AlwaysRandomizeAddress = true; # random mac
      };
    };
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0581-2B71";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.rtl-sdr.enable = true;
}
