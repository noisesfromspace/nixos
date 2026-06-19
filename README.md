## Description

NixOS is a Linux distribution with a unique package management system, Nix,
offering precise control and reproducible configurations. It follows a
declarative and functional programming approach, ensuring system reliability
and easy rollback.

> 🌱 **Tired of GitHub?** This repository is available through Radicle. View it here: [rad:z2Jkf9zxGPxEhCfGLpgRAcHRj8x2n](https://git.boers.email/nodes/seed.boers.email/rad:z2Jkf9zxGPxEhCfGLpgRAcHRj8x2n)

You could directly use this but it's better to extract the pieces
you want in your own config. Check out [nix-starter-config](https://github.com/Misterio77/nix-starter-configs)
for a good initial starting point for NixOS with flakes.

### Services

#### Router

| Service     | Description                                   | Configuration                                            |
| ----------- | --------------------------------------------- | -------------------------------------------------------- |
| ACME        | ACME server for internal TLS certificates.    | [acme.nix](hosts/dosukoi/modules/acme.nix)               |
| Blocklist   | Manages a network-wide blocklist.             | [blocklist.nix](hosts/dosukoi/modules/blocklist.nix)     |
| Firewall    | Manages network traffic rules using nftables. | [firewall.nix](hosts/dosukoi/modules/firewall.nix)       |
| Interfaces  | Configures network interfaces and PPPoE.      | [interfaces.nix](hosts/dosukoi/modules/interfaces.nix)   |
| ntopng      | Network traffic monitoring tool.              | [ntopng.nix](hosts/dosukoi/modules/ntopng.nix)           |
| Vaultwarden | Password manager (Bitwarden compatible).      | [vaultwarden.nix](hosts/dosukoi/modules/vaultwarden.nix) |
| WireGuard   | VPN tunnel.                                   | [wireguard.nix](hosts/dosukoi/modules/wireguard.nix)     |

#### Main file server

| Service                             | Description                                        | Configuration                                           |
| ----------------------------------- | -------------------------------------------------- | ------------------------------------------------------- |
| Atuin                               | Shell history synchronization.                     | [atuin.nix](hosts/hadouken/modules/atuin.nix)           |
| Bincache                            | Binary cache with Attic.                           | [bincache.nix](hosts/hadouken/modules/bincache.nix)     |
| Garage                              | Object storage (Garage API + UI) for media assets. | [garage.nix](hosts/hadouken/modules/garage.nix)         |
| Calendar (Radicale)                 | CalDAV and CardDAV server.                         | [calendar.nix](hosts/hadouken/modules/calendar.nix)     |
| Database stack                      | PostgreSQL, MinIO buckets, pgAdmin UI.             | [database.nix](hosts/hadouken/modules/database.nix)     |
| Immich                              | Self-hosted photo and video backup solution.       | [immich.nix](hosts/hadouken/modules/immich.nix)         |
| Mastodon (glitch-soc) & Fedifetcher | Federated social media server.                     | [mastodon.nix](hosts/hadouken/modules/mastodon.nix)     |
| Matrix Synapse                      | Secure, decentralized communication server.        | [matrix.nix](hosts/hadouken/modules/matrix.nix)         |
| Media stack                         | Jellyfin, Jellyseerr and Syncthing.                | [media.nix](hosts/hadouken/modules/media.nix)           |
| Microbin                            | Self-hosted pastebin.                              | [microbin.nix](hosts/hadouken/modules/microbin.nix)     |
| Monitoring                          | Grafana, Loki, Promtail, Prometheus, InfluxDB.     | [monitoring.nix](hosts/hadouken/modules/monitoring.nix) |
| Paperless-NGX                       | Document management system.                        | [paperless.nix](hosts/hadouken/modules/paperless.nix)   |
| Shares                              | NFS exports for internal hosts.                    | [shares.nix](hosts/hadouken/modules/shares.nix)         |
| Storage                             | ZFS datasets, syncoid replication.                 | [storage.nix](hosts/hadouken/modules/storage.nix)       |

#### Cloud #1

| Service           | Description                           | Configuration                                         |
| ----------------- | ------------------------------------- | ----------------------------------------------------- |
| Authoritative DNS | Authoritative DNS server.             | [authdns.nix](nixos/modules/authdns.nix)              |
| Derper            | Tailscale DERP server.                | [derper.nix](nixos/modules/derper.nix)                |
| Headscale         | Self-hosted Tailscale control server. | [headscale.nix](hosts/rekkaken/modules/headscale.nix) |
| Ladder            | Self-hosted 12ft.io alternative.      | [ladder.nix](hosts/rekkaken/modules/ladder.nix)       |
| Notifications     | Gotify and SMTP gateway bridge.       | [notifs.nix](hosts/rekkaken/modules/notifs.nix)       |
| Uptime Kuma       | Service monitoring tool.              | [uptime.nix](hosts/rekkaken/modules/uptime.nix)       |

#### Cloud #2

| Service           | Description                                   | Configuration                                        |
| ----------------- | --------------------------------------------- | ---------------------------------------------------- |
| Authoritative DNS | Authoritative DNS server.                     | [authdns.nix](nixos/modules/authdns.nix)             |
| Derper            | Tailscale DERP server.                        | [derper.nix](nixos/modules/derper.nix)               |
| Caddy             | Reverse proxy for boers.email + static sites. | [caddy.nix](hosts/shoryuken/modules/caddy.nix)       |
| Endlessh          | SSH tarpit.                                   | [endlessh.nix](hosts/shoryuken/modules/endlessh.nix) |
| Radicle           | Radicle seed node + explorer.                 | [radicle.nix](hosts/shoryuken/modules/radicle.nix)   |
| Umami             | Self-hosted web analytics.                    | [umami.nix](hosts/shoryuken/modules/umami.nix)       |

#### Bitcoin Node

| Service      | Description                                        | Configuration                                      |
| ------------ | -------------------------------------------------- | -------------------------------------------------- |
| AdGuard Home | Network-wide ad and tracker blocking DNS sinkhole. | [adguard.nix](hosts/tatsumaki/modules/adguard.nix) |

#### WiFi AP

| Service        | Description               | Configuration                             |
| -------------- | ------------------------- | ----------------------------------------- |
| Home Assistant | Home automation platform. | [hass.nix](hosts/suzaku/modules/hass.nix) |

#### Utilities + GPS timeserver

| Service   | Description                                         | Configuration                                        |
| --------- | --------------------------------------------------- | ---------------------------------------------------- |
| Cyberchef | The Cyber Swiss Army Knife.                         | [cyberchef.nix](hosts/tenshin/modules/cyberchef.nix) |
| IT-Tools  | A collection of useful online tools for developers. | [ittools.nix](hosts/tenshin/modules/ittools.nix)     |
| NTP       | Network Time Protocol daemon.                       | [ntp.nix](hosts/tenshin/modules/ntp.nix)             |
