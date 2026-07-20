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

  boot = {
    kernelModules = [
      "intel_cvs"
    ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelParams = [
      "i915.force_probe=7d51"
      "nvidia.NVreg_TemporaryFilePath=/var/tmp"
      # "mem_sleep_default=deep"
      # "resume_offset=112625664"
    ];

    initrd = {

      availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "vmd"
        "nvme"
        "usb_storage"
        "sd_mod"
        "rtsx_pci_sdmmc"
      ];

      luks = {
        devices."luks-c871b8b9-389b-47d7-a962-7a6df02a37f3" = {
          device = "/dev/disk/by-uuid/c871b8b9-389b-47d7-a962-7a6df02a37f3";
          crypttabExtraOpts = [ "fido2-device=auto" ];
        };
        devices."luks-21deee7e-5835-4df0-9d84-f9b225a256e3" = {
          device = "/dev/disk/by-uuid/21deee7e-5835-4df0-9d84-f9b225a256e3";
          crypttabExtraOpts = [ "fido2-device=auto" ];
        };
      };
      systemd.enable = true;
      systemd.services.delete-nvidia-ko = {
        description = "Remove nvidia modules from initrd";
        wantedBy = [ "initrd.target" ];
        before = [ "sys-kernel-modules-load.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''/bin/sh -c "rm -f /lib/modules/*/kernel/drivers/gpu/drm/nvidia*.ko"'';
        };
      };
    };
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  # https://wiki.nixos.org/wiki/NVIDIA
  hardware.nvidia = {
    open = true;
    # https://github.com/NVIDIA/open-gpu-kernel-modules/pull/951
    # package = config.boot.kernelPackages.nvidiaPackages.beta;
    powerManagement.enable = true; # should fix hybernation
    prime = {
      offload.enable = true;
      intelBusId = "PCI:00:02:0";
      nvidiaBusId = "PCI:01:00:0";
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/b5341b54-076b-4039-a5cd-e42604e1faeb";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/9BD6-6260";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    {
      device = "/dev/mapper/luks-21deee7e-5835-4df0-9d84-f9b225a256e3";
    }
  ];

  boot.resumeDevice = "/dev/mapper/luks-21deee7e-5835-4df0-9d84-f9b225a256e3";

  systemd.network.networks = {
    "50-dhcp" = {
      matchConfig.Name = "en*";
      networkConfig.DHCP = "yes";
      dhcpV4Config.UseDNS = false;
      dhcpV6Config.UseDNS = false;
      linkConfig.RequiredForOnline = "no";
    };
    "50-wireless" = {
      matchConfig.Name = "wlan0";
      dhcpV4Config.UseDNS = false;
      dhcpV6Config.UseDNS = false;
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

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
