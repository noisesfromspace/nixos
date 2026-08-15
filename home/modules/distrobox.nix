{ config, pkgs, ... }:

{
  home.packages = [ pkgs.podman-compose ];

  programs.distrobox = {
    enable = true;

    settings = {
      container_manager = "podman";
      container_generate_entry = 0;
    };

    containers = {
      arch = {
        image = "docker.io/library/archlinux:latest"; # rolling, no releases
        home = "${config.home.homeDirectory}/.local/share/distrobox/arch";
        pre_init_hooks = "export SHELL=/bin/bash;";
      };
      fedora = {
        image = "docker.io/library/fedora:44"; # latest stable
        home = "${config.home.homeDirectory}/.local/share/distrobox/fedora";
        pre_init_hooks = "export SHELL=/bin/bash;";
      };
      ubuntu = {
        image = "docker.io/library/ubuntu:24.04"; # latest LTS
        home = "${config.home.homeDirectory}/.local/share/distrobox/ubuntu";
        pre_init_hooks = "export SHELL=/bin/bash;";
      };
    };
  };
}
