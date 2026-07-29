{ pkgs, ... }:
{
  networking.hostName = "nurma";
  hosts.desktop.enable = true;
  hosts.secureboot.enable = true;
  hosts.yubikey.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # environment.systemPackages = [
  #   inputs.credentialsd.packages.${pkgs.system}.firefox-patched
  # ];

  # ssh-keygen -t ed25519 -C remote-build -f remote-build
  programs.ssh.extraConfig = ''
    Host *.machine.thuis
      ControlMaster auto
      ControlPath ~/.ssh/control-%h-%p-%r
      ControlPersist 10m

    Host eu.nixbuild.net
      PubkeyAcceptedKeyTypes ssh-ed25519
      ServerAliveInterval 60
      IPQoS throughput
      IdentityFile /root/.ssh/remote-build
  '';

  nix.settings = {
    substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  hosts.borg = {
    enable = true;
    repository = "ssh://nads486h@nads486h.repo.borgbase.com/./repo";
    tatsumaki = true;
    paths = [ "/home/martijn" ];
    identityPath = "/home/martijn/.ssh/id_ed25519_age";
    exclude = [
      ".cache"
      "*/cache2" # librewolf
      "*/Cache"
      ".wine"
      ".config/Slack/logs"
      ".config/Code/CachedData"
      ".container-diff"
      ".npm/_cacache"
      ".ollama"
      "Models"
      "Sync"
      "*/node_modules"
      "*/_build"
      "*/venv"
      "*/.venv"
      "/home/*/.local"
      "/home/*/Downloads"
      "/home/*/Data"
      "/home/*/.ssh"
    ];
  };

  environment.systemPackages = with pkgs; [
    # https://github.com/quickemu-project/quickemu/wiki/05-Advanced-quickemu-configuration
    quickemu
  ];

  users.users.martijn.extraGroups = [
    "libvirtd"
    "libvirt"
    "kvm"
    "adbusers"
  ];

  programs.virt-manager.enable = true;

  virtualisation = {
    waydroid.enable = false; # android
    libvirtd.enable = true; # virt-manager
    spiceUSBRedirection.enable = true;
  };

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true; # copy&paste

  hosts.tailscale.enable = true;
  hosts.prometheus.enable = true;

  programs = {
    steam.enable = true;
    winbox = {
      enable = true;
      package = pkgs.winbox4;
      openFirewall = true;
    };
  };

  hosts.openssh = {
    enable = false;
    allowUsers = [
      "martijn@100.64.0.0/10"
      "martijn@10.30.0.0/24"
    ];
  };

  services.xserver.videoDrivers = [ "amdgpu" ];

  # Enable binfmt emulation of aarch64-linux. (for the raspberry pi)
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  hosts.auditd = {
    enable = true;
    rules = [
      "-w /home/martijn/.ssh -p rwa -k ssh_file_access"
      "-w /etc/nixos/flake -p wa -k nix_config_changes"
      "-w /dev/video0 -p war"
    ];
  };

  age = {
    identityPaths = [ "/home/martijn/.ssh/id_ed25519_age" ];
  };
}
