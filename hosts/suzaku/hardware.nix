{
  lib,
  modulesPath,
  pkgs,
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

  hardware.enableRedistributableFirmware = true;

  # ----------------------------------------------------------------
  # 1. KERNEL: Force 4k Pages
  # ----------------------------------------------------------------
  # We use the RPi4 kernel package because it is pre-configured for
  # 4k pages. This is required because the MediaTek binary firmware
  # crashes on the default Pi 5 (16k) kernel.
  # This triggers the compilation, but it is necessary.
  boot.kernelPackages = pkgs.linuxPackages_rpi4;

  # ----------------------------------------------------------------
  # 2. HARDWARE / FIRMWARE
  # ----------------------------------------------------------------
  hardware.raspberry-pi.config.all = {
    base-dt-params = {
      pciex1 = {
        enable = true;
        value = "on";
      };
      pcie_gen = {
        enable = true;
        value = "2";
      };
    };

    options = {
      # Headless optimization: Save RAM for Home Assistant/WiFi
      gpu_mem = {
        enable = true;
        value = "64";
      };
      display_auto_detect = {
        enable = true;
        value = "0";
      };
    };

    dt-overlays = {
      # Disable internal WiFi to save resources/conflicts
      disable-wifi = {
        enable = true;
        params = { };
      };

      # Reserve 512MB RAM for the WiFi card (CMA)
      vc4-kms-v3d = {
        enable = true;
        params = {
          cma-512 = {
            enable = true;
          };
        };
      };
    };
  };

  # ----------------------------------------------------------------
  # 3. MANUAL OVERLAY: Force 32-bit DMA
  # ----------------------------------------------------------------
  # This manually compiles a Device Tree Overlay to tell the Pi 5
  # PCIe controller that this slot can only address the first 3GB
  # of RAM. This fixes the "Error -12" memory crash without using
  # the binary overlay that previously hung your system.
  hardware.deviceTree = {
    enable = true;
    overlays = [
      {
        name = "pcie-32bit-dma-pi5";
        dtsText = ''
          /dts-v1/;
          /plugin/;

          / {
            compatible = "brcm,bcm2712";

            fragment@0 {
              target = <&pcie1>;
              __overlay__ {
                #address-cells = <3>;
                #size-cells = <2>;
                dma-ranges = <0x02000000 0x0 0x00000000 0x0 0x00000000 0x0 0x80000000>;
              };
            };
          };
        '';
      }
    ];
  };

  # ----------------------------------------------------------------
  # 4. KERNEL PARAMETERS
  # ----------------------------------------------------------------
  boot = {
    kernelParams = [
      # DISABLE WED: Prevents MediaTek-specific offloading crash
      "mt7915e.wed_enable=0"

      # SOFT IOMMU: Forces CPU to handle the 32-bit address translation
      "iommu=soft"

      # SWIOTLB: Increase software buffer size (65536 * 2KB = 128MB)
      "swiotlb=65536"

      # ATOMIC POOL: Ensure enough immediate memory for the driver
      "coherent_pool=32M"

      # POWER: Disable PCIe power saving to prevent disconnects
      "pcie_aspm=off"
    ];

    kernelModules = [
      "mt7915e"
      "mt7915_common"
      "mt76_connac"
      "mt76"
    ];
    blacklistedKernelModules = [
      "brcmfmac"
      "brcmutil"
    ];
    loader.raspberry-pi.bootloader = "kernel";
  };

  fileSystems = {
    "/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = [
        "noatime"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=1min"
      ];
    };
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  # disko.devices = {
  #   disk = {
  #     main = {
  #       type = "disk";
  #       device = "/dev/mmcblk0";
  #       content = {
  #         type = "gpt";
  #         partitions = {
  #           FIRMWARE = {
  #             label = "FIRMWARE";
  #             priority = 1;
  #             type = "0700"; # Microsoft basic data
  #             attributes = [ 0 ];
  #             size = "1024M";
  #             content = {
  #               type = "filesystem";
  #               format = "vfat";
  #               mountpoint = "/boot/firmware";
  #               mountOptions = [
  #                 "noatime"
  #                 "noauto"
  #                 "x-systemd.automount"
  #                 "x-systemd.idle-timeout=1min"
  #               ];
  #             };
  #           };
  #           ESP = {
  #             label = "ESP";
  #             type = "EF00";
  #             attributes = [
  #               2
  #             ];
  #
  #             size = "1024M";
  #             content = {
  #               type = "filesystem";
  #               format = "vfat";
  #               mountpoint = "/boot";
  #               mountOptions = [
  #                 "noatime"
  #                 "noauto"
  #                 "x-systemd.automount"
  #                 "x-systemd.idle-timeout=1min"
  #                 "umask=0077"
  #               ];
  #             };
  #           };
  #           root = {
  #             size = "100%";
  #             content = {
  #               type = "filesystem";
  #               format = "ext4";
  #               mountpoint = "/";
  #             };
  #           };
  #         };
  #       };
  #     };
  #   };
  # };

  zramSwap.enable = true;

  systemd.network.networks."10-end0" = {
    matchConfig.Name = "end0";
    networkConfig = {
      DHCP = "no"; # no ipv4 dhcp
      IPv6AcceptRA = true;
    };
    address = [
      "10.10.0.4/24"
    ];
    routes = [
      { Gateway = "10.10.0.1"; }
    ];
    linkConfig.RequiredForOnline = "routable";
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
