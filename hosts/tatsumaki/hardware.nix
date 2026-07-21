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
    kernelModules = [ "kvm-intel" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd = {
      availableKernelModules = [
        "ahci"
        "xhci_pci"
        "usbhid"
        "usb_storage"
        "sr_mod"
        "sdhci_pci"
      ];
      systemd.enable = true;
    };
  };

  systemd.network.networks =
    let
      defaultNetwork =
        { adapter, ip }:
        {
          "10-${adapter}" = {
            matchConfig.Name = adapter;
            networkConfig = {
              DHCP = "no";
              IPv6AcceptRA = true;
            };
            address = [
              "${ip}/24"
            ];
            routes = [
              { Gateway = "10.10.0.1"; }
            ];
            linkConfig.RequiredForOnline = "routable";
          };
        };
    in
    lib.attrsets.mergeAttrsList (
      map defaultNetwork [
        # {
        #   adapter = "enp2s0";
        #   ip = "2";
        # }
        {
          adapter = "enp3s0";
          ip = config.global.lan_ips.tatsumaki;
        }
      ]
    );

  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/mmcblk0";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02";
              priority = 1;
            };
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };

  fileSystems."/mnt/evo" = {
    device = "/dev/disk/by-partuuid/75dd214a-61d2-4af7-9c23-1d441d8f7d47";
    fsType = "ext4";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
