{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.netns;

  vethHostAddr = "10.98.0.1";
  vethNsAddr = "10.98.0.2";

  mullvadPeers = [
    {
      endpoint = "45.129.56.67:51820";
      publicKey = "egl+0TkpFU39F5O6r6+hIBMPQLOa8/t5CymOZV6CC3Y=";
    }
    {
      endpoint = "149.102.246.2:51820";
      publicKey = "li+thkAD7s6IZDgUoiKw4YSjM/U1q203PuthMzIJIU0=";
    }
    {
      endpoint = "146.70.129.98:51820";
      publicKey = "tWVga+pS/Ztrbx/L/PBlaWPGhkI3PCPBzbQlCeXWqn8=";
    }
    {
      endpoint = "146.70.189.2:51820";
      publicKey = "2r0vPpM71ZXpseWXTXw3iwn2sjIHOTpw1V9sp03bLWw=";
    }
    {
      endpoint = "195.47.194.131:51820";
      publicKey = "Ae9YcQjcQT+W8MU0EhKXx6KPWo6ticS1NI91e+Zy5GA=";
    }
    {
      endpoint = "146.70.116.98:51820";
      publicKey = "TNrdH73p6h2EfeXxUiLOCOWHcjmjoslLxZptZpIPQXU=";
    }
    {
      endpoint = "45.134.79.67:51820";
      publicKey = "y6dcYS7MPeApbLoWLahjku5w5cufnNkwHzj1iwDPpS0=";
    }
    {
      endpoint = "146.70.196.194:51820";
      publicKey = "u+h0GmQJ8UBaMTi2BP9Ls6UUszcGC51y6vTmNr/y+AU=";
    }
    {
      endpoint = "149.102.229.129:51820";
      publicKey = "jPhK/ziQfJ1Z5GCPj+qR3A7YV2mIQSQtEPCRuG7TUW8=";
    }
    {
      endpoint = "45.134.212.66:51820";
      publicKey = "fO4beJGkKZxosCZz1qunktieuPyzPnEVKVQNhzanjnA=";
    }
    {
      endpoint = "146.70.188.130:51820";
      publicKey = "J8KysHmHZWqtrVKKOppneDXSks/PDsB1XTlRHpwiABA=";
    }
    {
      endpoint = "176.125.235.71:51820";
      publicKey = "jOUZjMq2PWHDzQxu3jPXktYB7EKeFwBzGZx56cTXXQg=";
    }
    {
      endpoint = "194.127.167.87:51820";
      publicKey = "vqGmmcERr/PAKDzy6Dxax8g4150rC93kmKYabZuAzws=";
    }
    {
      endpoint = "146.70.193.2:51820";
      publicKey = "Orrce1127WpljZa+xKbF21zJkJ9wM1M3VJ5GJ/UsIDU=";
    }
    {
      endpoint = "91.90.123.2:51820";
      publicKey = "GE2WP6hmwVggSvGVWLgq2L10T3WM2VspnUptK5F4B0U=";
    }
  ];

  # Populated at runtime by preSetup — picks a random peer from the list.
  # First peer is used as a placeholder default for the NixOS WG module.
  mullvadEndpoint = mullvadPeersHead.endpoint;
  mullvadPublicKey = mullvadPeersHead.publicKey;
  mullvadPeersHead = builtins.head mullvadPeers;
  mullvadAddress = "10.64.205.236/32";
  tunnelDns = "10.64.0.1";

  nsName = "tunnel";
  bridgeName = "${nsName}-br";
  vethHost = "veth-${nsName}";
  vethNs = "veth-ns";
  fwMark = "42";

  workNsName = "work";
  workVethHost = "veth-work";
  workVethNs = "veth-work-ns";
  workVethHostAddr = "10.99.0.1";
  workVethNsAddr = "10.99.0.2";
  workSubnet = "10.99.0.0/30";
  workFwMark = "43";
  workBootstrapDns = "1.1.1.1";

  # setns wrappers enter a fixed network namespace, bind-mount its
  # resolv.conf, then drop privileges before running the requested command.
  mkNetnsExe =
    {
      commandName,
      namespace,
    }:
    pkgs.runCommandCC "${commandName}-nsenter"
      {
        src = pkgs.writeText "${commandName}.c" /* c */ ''
          #define _GNU_SOURCE
          #include <fcntl.h>
          #include <linux/capability.h>
          #include <sched.h>
          #include <sys/mount.h>
          #include <sys/prctl.h>
          #include <sys/stat.h>
          #include <sys/syscall.h>
          #include <sys/types.h>
          #include <unistd.h>
          int main(int argc, char **argv) {
              if (argc < 2) return 1;
              int fd = open("/var/run/netns/${namespace}", O_RDONLY | O_CLOEXEC);
              if (fd < 0) return 1;
              if (setns(fd, CLONE_NEWNET)) { close(fd); return 2; }
              close(fd);
              /* Enter a private mount namespace and bind-mount the
               * namespace's resolv.conf over /etc/resolv.conf (same as
               * `ip netns exec`). Must happen while still privileged. */
              if (unshare(CLONE_NEWNS)) return 5;
              if (mount("none", "/", NULL, MS_REC | MS_PRIVATE, NULL)) return 6;
              struct stat st;
              if (stat("/etc/netns/${namespace}/resolv.conf", &st) == 0) {
                  mount("/etc/netns/${namespace}/resolv.conf", "/etc/resolv.conf", NULL, MS_BIND, NULL);
              }
              /* Hide host resolver sockets so getaddrinfo() falls through
               * to NSS dns and reads the namespace's resolv.conf. */
              mount("tmpfs", "/run/nscd", "tmpfs", 0, NULL);
              mount("/dev/null", "/run/systemd/resolve/io.systemd.Resolve", NULL, MS_BIND, NULL);
              /* Drop all capabilities (especially the ambient set, which
               * survives exec) before running the requested command. */
              if (prctl(PR_CAP_AMBIENT, PR_CAP_AMBIENT_CLEAR_ALL, 0, 0, 0) != 0) return 7;
              struct __user_cap_header_struct cap_hdr = { _LINUX_CAPABILITY_VERSION_3, 0 };
              struct __user_cap_data_struct cap_data[2] = { {0,0,0}, {0,0,0} };
              if (syscall(SYS_capset, &cap_hdr, cap_data) != 0) return 8;
              gid_t g = getgid();
              uid_t u = getuid();
              if (setresgid(g, g, g) || setresuid(u, u, u)) return 3;
              execvp(argv[1], argv + 1);
              return 4;
          }
        '';
      }
      ''
        mkdir -p $out/bin
        $CC -O2 -o $out/bin/${commandName} $src
      '';

  tunnel-exe = mkNetnsExe {
    commandName = "tunnel";
    namespace = nsName;
  };

  work-exe = mkNetnsExe {
    commandName = "work";
    namespace = workNsName;
  };

  # NixOS' OpenVPN module handles pushed DNS with up/down scripts and
  # update-resolv-conf. That helper is host-global, so this equivalent writes
  # the namespace-specific resolv.conf directly instead.
  work-openvpn-hook = pkgs.writeShellScript "work-openvpn-hook" ''
    set -u

    resolv_conf=/etc/netns/${workNsName}/resolv.conf

    write_bootstrap_dns() {
      printf 'nameserver %s\n' '${workBootstrapDns}' > "$resolv_conf"
    }

    case "''${script_type:-}" in
      up)
        # Open only the interface OpenVPN actually created. The namespace
        # otherwise permits no non-OpenVPN traffic through its veth.
        ${pkgs.nftables}/bin/nft add element inet work-fw vpn-ifaces \{ "$dev" \} 2>/dev/null || true

        nameservers=()
        search_domains=()
        for var in ''${!foreign_option_*}; do
          read -r kind option value _ <<< "''${!var}"
          if [[ $kind != dhcp-option || -z ''${value:-} ]]; then
            continue
          fi
          case "$option" in
            DNS) nameservers+=("$value") ;;
            DOMAIN | DOMAIN-SEARCH) search_domains+=("$value") ;;
          esac
        done

        if (( ''${#nameservers[@]} == 0 )); then
          echo "OpenVPN did not provide a DNS server; retaining bootstrap DNS" >&2
          exit 0
        fi

        {
          if (( ''${#search_domains[@]} > 0 )); then
            printf 'search'
            printf ' %s' "''${search_domains[@]}"
            printf '\n'
          fi
          printf 'nameserver %s\n' "''${nameservers[@]}"
        } > "$resolv_conf"
        ;;
      down)
        write_bootstrap_dns
        if [[ -n ''${dev:-} ]]; then
          ${pkgs.nftables}/bin/nft delete element inet work-fw vpn-ifaces \{ "$dev" \} 2>/dev/null || true
        fi
        ;;
    esac
  '';

  work-connect = pkgs.writeShellApplication {
    name = "work-connect";
    runtimeInputs = with pkgs; [
      iproute2
      openvpn
    ];
    text = ''
      if [[ ! -e /var/run/netns/${workNsName} ]]; then
        echo "The ${workNsName} network namespace is not running" >&2
        exit 1
      fi

      exec /run/wrappers/bin/sudo ip netns exec ${workNsName} openvpn \
        --config ${config.age.secrets.openvpn-work1.path} \
        --mark ${workFwMark} \
        --script-security 2 \
        --up ${work-openvpn-hook} \
        --down ${work-openvpn-hook} \
        --up-restart
    '';
  };
in
{
  options.hosts.netns = {
    enable = mkEnableOption "Mullvad VPN network namespace — isolates traffic through Mullvad WireGuard";
    allowedIngressPorts = mkOption {
      type = types.listOf types.port;
      default = [ ];
      description = ''
        TCP ports to accept from the host bridge into the tunnel namespace.
        Use this to expose service ports (e.g. 9091 for transmission RPC)
        that run inside the namespace via NetworkNamespacePath=.
      '';
    };
    socks5 = {
      enable = mkEnableOption "SOCKS5 proxy inside the tunnel namespace — reachable from the host at 10.98.0.2:<port>";
      port = mkOption {
        type = types.port;
        default = 1080;
        description = "SOCKS5 listen port inside the tunnel namespace.";
      };
    };
    http = {
      enable = mkEnableOption "HTTP proxy inside the tunnel namespace — reachable from the host at 10.98.0.2:<port>";
      port = mkOption {
        type = types.port;
        default = 8118;
        description = "HTTP proxy listen port inside the tunnel namespace.";
      };
    };
    work.enable = mkEnableOption "interactive OpenVPN work network namespace";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      tunnel-exe
    ]
    ++ optionals cfg.work.enable [
      work-exe
      work-connect
    ];

    security.wrappers.tunnel = {
      source = "${tunnel-exe}/bin/tunnel";
      capabilities = "cap_sys_admin+ep";
      owner = "root";
      group = "root";
    };

    security.wrappers.work = mkIf cfg.work.enable {
      source = "${work-exe}/bin/work";
      capabilities = "cap_sys_admin+ep";
      owner = "root";
      group = "root";
    };

    security.pki.certificateFiles = mkIf cfg.work.enable [ "${inputs.secrets}/keys/work.crt" ];
    boot.kernelModules = optionals cfg.work.enable [ "tun" ];

    age.secrets."mullvad-wg" = {
      file = "${inputs.secrets}/mullvad-wg.age";
      owner = "root";
      group = "root";
      mode = "600";
    };

    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    # ── Namespace factory (template — one shot, never auto-restarted) ──
    systemd.services."netns@" = {
      description = "%I network namespace";
      before = [ "network.target" ];
      restartIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.iproute2}/bin/ip netns add %I";
        ExecStop = "${pkgs.iproute2}/bin/ip netns del %I";
      };
    };

    # ── WireGuard — NixOS declarative module handles interface lifecycle ──
    networking.wireguard.interfaces.tun0 = {
      interfaceNamespace = nsName;
      ips = [ mullvadAddress ];
      privateKeyFile = config.age.secrets."mullvad-wg".path;
      # Fixed listen port in the host firewall's allowed range (40000-50000).
      # Without this the kernel picks a random port that may be firewalled.
      listenPort = 45516;
      fwMark = fwMark;
      mtu = 1280;
      peers = [
        {
          name = "mullvad";
          publicKey = mullvadPublicKey;
          endpoint = mullvadEndpoint;
          allowedIPs = [ "0.0.0.0/0" ];
          persistentKeepalive = 10;
        }
      ];

      # Runs before the WG interface is created — sets up the veth pair,
      # installs the kill-switch firewall in the namespace, then adds a
      # temporary default route so WG-encrypted packets can reach
      # Mullvad's endpoint through the host's internet.
      preSetup = ''
        # Pick a random Mullvad peer from the pool
        PEERS=(${lib.concatMapStringsSep " " (p: ''"${p.endpoint}|${p.publicKey}"'') mullvadPeers})
        IDX=$((RANDOM % ${toString (builtins.length mullvadPeers)}))
        IFS="|" read -r ENDPOINT PUBKEY <<< "''${PEERS[$IDX]}"
        echo "Selected Mullvad peer $((IDX + 1))/${toString (builtins.length mullvadPeers)}: $ENDPOINT"

        # Idempotent: if the WG interface already exists inside the
        # namespace, everything is already set up — skip.
        ip netns exec ${nsName} ip link show tun0 >/dev/null 2>&1 && exit 0

        # Clean up a leftover veth from a previous module version
        ip link del ${vethHost} 2>/dev/null || true

        ip link add ${vethHost} type veth peer name ${vethNs}
        ip link set ${vethNs} netns ${nsName}
        ip link set ${vethHost} up

        ip -n ${nsName} addr add ${vethNsAddr}/30 dev ${vethNs}
        ip -n ${nsName} link set ${vethNs} up
        ip -n ${nsName} link set lo up

        # ── Kill-switch: install before the default route exists ──
        # From this point on, the namespace can only send WG-encrypted
        # packets (fwmark ${fwMark}) to Mullvad's endpoint via the veth.
        # Everything else is blocked until tun0 comes up in postSetup.
        NS="ip netns exec ${nsName}"
        $NS nft add table inet tunnel-fw 2>/dev/null || true
        $NS nft 'add chain inet tunnel-fw input  { type filter hook input  priority 0; policy drop; }'
        $NS nft 'add chain inet tunnel-fw forward { type filter hook forward priority 0; policy drop; }'
        $NS nft 'add chain inet tunnel-fw output { type filter hook output priority 0; policy drop; }'

        $NS nft add rule inet tunnel-fw input  iif lo accept
        $NS nft add rule inet tunnel-fw output oif lo accept
        $NS nft add rule inet tunnel-fw input  ct state established,related accept
        $NS nft add rule inet tunnel-fw output ct state established,related accept

        # WG-encrypted packets — identified by kernel fwmark — reach the endpoint via veth
        $NS nft add rule inet tunnel-fw output \
          oif ${vethNs} meta mark ${fwMark} accept

        # Reject any DNS that tries to bypass the tunnel — instant failure
        # instead of timeout (matches Mullvad's kill-switch behavior).
        $NS nft add rule inet tunnel-fw output \
          oif ${vethNs} meta l4proto { tcp, udp } th dport 53 reject

        ip -n ${nsName} route add default via ${vethHostAddr}
      '';

      # Runs after the WG interface is created. Configures the peer,
      # waits for the handshake, fixes routing, opens the tunnel in
      # the kill-switch, and applies NAT + host-side bridge firewall.
      postSetup = ''
        NS="ip netns exec ${nsName}"

        # DNS — /etc/netns/<name>/ is bind-mounted over /etc/resolv.conf
        # for any process that enters the namespace via `ip netns exec`.
        mkdir -p /etc/netns/${nsName}
        echo "nameserver ${tunnelDns}" > /etc/netns/${nsName}/resolv.conf

        # WireGuard peer + wait for handshake
        $NS wg set tun0 peer "$PUBKEY" \
          endpoint "$ENDPOINT" \
          allowed-ips 0.0.0.0/0 \
          persistent-keepalive 10

        for i in $(seq 1 15); do
          HS=$($NS wg show tun0 latest-handshakes | awk '{print $2}')
          if [[ -n $HS && $HS != "0" ]]; then break; fi
          sleep 1
        done

        # Swap routing: endpoint via veth (so WG encrypted packets
        # can reach Mullvad's server), everything else via tun0.
        ip -n ${nsName} route del default via ${vethHostAddr}
        ip -n ${nsName} route add "''${ENDPOINT%:*}" via ${vethHostAddr}
        ip -n ${nsName} route add default dev tun0

        # Opening: allow all outbound traffic through the now-ready WG tunnel.
        # The rest of the kill-switch (default-drop, lo, ct, wg-mark, dns-reject)
        # was already installed in preSetup.
        $NS nft add rule inet tunnel-fw output oif tun0 accept

        # Catch-all — instant reject instead of silent timeout for any packet
        # that somehow misses the allow rules (matches Mullvad's kill-switch).
        $NS nft add rule inet tunnel-fw output reject

        # Allowed ingress ports from host into the namespace
        ${lib.concatMapStringsSep "\n        " (
          port: "$NS nft add rule inet tunnel-fw input iif ${vethNs} tcp dport ${toString port} accept"
        ) cfg.allowedIngressPorts}

        # NAT — masquerade namespace traffic to the internet
        nft delete table ip tunnel-nat 2>/dev/null || true
        nft add table ip tunnel-nat
        nft 'add chain ip tunnel-nat postrouting { type nat hook postrouting priority srcnat; }'
        nft 'add chain ip tunnel-nat forward { type filter hook forward priority filter; policy drop; }'
        nft add rule ip tunnel-nat postrouting ip saddr 10.98.0.0/30 masquerade
        # Forward only the WG tunnel traffic: outbound from the namespace,
        # and established return traffic back into it. Everything else
        # (Docker/Libvirt/LAN devices routed here) is dropped, so they
        # cannot reach the unauthenticated services on the bridge.
        nft add rule ip tunnel-nat forward iifname ${bridgeName} accept
        nft add rule ip tunnel-nat forward oifname ${bridgeName} ct state established,related accept
        ${optionalString cfg.work.enable ''
          # The work namespace owns its NAT table, but forwarded packets also
          # traverse this existing policy-drop base chain.
          nft add rule ip tunnel-nat forward iifname ${workVethHost} accept
          nft add rule ip tunnel-nat forward oifname ${workVethHost} ct state established,related accept
        ''}

        # Host-side bridge access control — restrict which host
        # processes can reach services inside the tunnel namespace.
        nft delete table inet tunnel-host-fw 2>/dev/null || true
        nft add table inet tunnel-host-fw
        nft 'add chain inet tunnel-host-fw output { type filter hook output priority 0; policy accept; }'
        nft add rule inet tunnel-host-fw output \
          oif ${bridgeName} ip daddr ${vethNsAddr} ct state established,related accept
        ${lib.concatMapStringsSep "\n        " (
          port:
          "nft add rule inet tunnel-host-fw output oif ${bridgeName} ip daddr ${vethNsAddr} tcp dport ${toString port} accept"
        ) cfg.allowedIngressPorts}
        nft add rule inet tunnel-host-fw output \
          oif ${bridgeName} ip daddr ${vethNsAddr} counter drop
      '';

      preShutdown = ''
        # Clean up host-side tables. The in-namespace tunnel-fw
        # table dies automatically when the namespace is deleted.
        nft delete table ip tunnel-nat 2>/dev/null || true
        nft delete table inet tunnel-host-fw 2>/dev/null || true
      '';
    };

    # Never auto-restart the WG service on rebuild — protects running VMs.
    systemd.services."wireguard-tun0" = {
      restartIfChanged = false;
      bindsTo = [ "netns@${nsName}.service" ];
      after = [ "netns@${nsName}.service" ];
      path = with pkgs; [
        nftables
        iproute2
        gawk
      ];
    };

    # The NixOS wireguard module creates a peer-helper service per peer.
    # It tries `wg set tun0 peer ...` on the host, but the interface
    # lives inside the namespace. Peer config is handled in postSetup.
    systemd.services."wireguard-tun0-peer-mullvad" = {
      serviceConfig.ExecStart = lib.mkForce "${pkgs.coreutils}/bin/true";
      serviceConfig.ExecStopPost = lib.mkForce "${pkgs.coreutils}/bin/true";
    };

    # ── Interactive OpenVPN work namespace ──────────────────────────────
    systemd.services.work-netns = mkIf cfg.work.enable {
      description = "OpenVPN work network namespace connectivity";
      wantedBy = [ "multi-user.target" ];
      bindsTo = [ "netns@${workNsName}.service" ];
      requires = [ "wireguard-tun0.service" ];
      after = [
        "netns@${workNsName}.service"
        "wireguard-tun0.service"
      ];
      restartIfChanged = false;
      path = with pkgs; [
        coreutils
        gnugrep
        iproute2
        nftables
        procps
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Remove only a leftover host end; deleting it also deletes its peer.
        ip link del ${workVethHost} 2>/dev/null || true
        ip link add ${workVethHost} type veth peer name ${workVethNs}
        ip link set ${workVethNs} netns ${workNsName}
        ip addr add ${workVethHostAddr}/30 dev ${workVethHost}
        ip link set ${workVethHost} up

        ip -n ${workNsName} addr add ${workVethNsAddr}/30 dev ${workVethNs}
        ip -n ${workNsName} link set ${workVethNs} up
        ip -n ${workNsName} link set lo up
        ip netns exec ${workNsName} sysctl -q -w net.ipv4.ping_group_range='0 2147483647'

        mkdir -p /etc/netns/${workNsName}
        printf 'nameserver %s\n' '${workBootstrapDns}' > /etc/netns/${workNsName}/resolv.conf

        # Kill-switch: OpenVPN's marked encrypted packets and its root-owned
        # bootstrap DNS may use the veth. Applications may only use the VPN
        # interface inserted into vpn-ifaces by the OpenVPN up hook.
        NS="ip netns exec ${workNsName}"
        $NS nft delete table inet work-fw 2>/dev/null || true
        $NS nft add table inet work-fw
        $NS nft 'add set inet work-fw vpn-ifaces { type ifname; }'
        $NS nft 'add chain inet work-fw input { type filter hook input priority filter; policy drop; }'
        $NS nft 'add chain inet work-fw forward { type filter hook forward priority filter; policy drop; }'
        $NS nft 'add chain inet work-fw output { type filter hook output priority filter; policy drop; }'
        $NS nft add rule inet work-fw input iif lo accept
        $NS nft add rule inet work-fw input ct state established,related accept
        $NS nft add rule inet work-fw output oif lo accept
        $NS nft add rule inet work-fw output oifname @vpn-ifaces accept
        $NS nft add rule inet work-fw output oif ${workVethNs} meta mark ${workFwMark} accept
        $NS nft add rule inet work-fw output oif ${workVethNs} meta skuid 0 udp dport 53 accept
        $NS nft add rule inet work-fw output oif ${workVethNs} meta skuid 0 tcp dport 53 accept
        $NS nft add rule inet work-fw output reject

        # Work NAT is independent, but forwarding must also be allowed through
        # tunnel-nat's existing policy-drop forward chain. The check handles
        # activation while wireguard-tun0 is intentionally not restarted.
        nft delete table ip work-nat 2>/dev/null || true
        nft add table ip work-nat
        nft 'add chain ip work-nat postrouting { type nat hook postrouting priority srcnat; }'
        nft add rule ip work-nat postrouting ip saddr ${workSubnet} masquerade
        if ! nft list chain ip tunnel-nat forward | grep -Fq 'iifname "${workVethHost}"'; then
          nft add rule ip tunnel-nat forward iifname ${workVethHost} accept
          nft add rule ip tunnel-nat forward oifname ${workVethHost} ct state established,related accept
        fi

        # Install the route only after the kill-switch is active.
        ip -n ${workNsName} route add default via ${workVethHostAddr}
      '';
      preStop = ''
        nft delete table ip work-nat 2>/dev/null || true
        ip link del ${workVethHost} 2>/dev/null || true
      '';
    };

    # ── Bridge between host and namespace — systemd-networkd ────────────
    systemd.network.netdevs."20-${bridgeName}".netdevConfig = {
      Kind = "bridge";
      Name = bridgeName;
    };

    systemd.network.networks."30-${bridgeName}" = {
      matchConfig.Name = bridgeName;
      address = [ "${vethHostAddr}/30" ];
      networkConfig.IPv4Forwarding = true;
      linkConfig.RequiredForOnline = "no";
    };

    systemd.network.networks."30-${vethHost}" = {
      matchConfig.Name = vethHost;
      networkConfig.Bridge = bridgeName;
      linkConfig.RequiredForOnline = "no";
    };

    # ── SOCKS5 proxy inside the namespace ─────────────────────────
    hosts.netns.allowedIngressPorts =
      lib.optionals cfg.socks5.enable [ cfg.socks5.port ]
      ++ lib.optionals cfg.http.enable [ cfg.http.port ];

    services.microsocks = mkIf cfg.socks5.enable {
      enable = true;
      ip = "0.0.0.0";
      port = cfg.socks5.port;
      # Filter outgoing connections to IPv4 only. The tunnel namespace has
      # no IPv6 route, and microsocks only tries the first getaddrinfo()
      # result (IPv6 on dual-stack domains) — causing ENETUNREACH.
      outgoingBindIp = "0.0.0.0";
      # No auth — the nftables host-side firewall already restricts
      # access to processes running on this machine only.
    };

    systemd.services.microsocks = mkIf cfg.socks5.enable {
      bindsTo = [ "netns@${nsName}.service" ];
      after = [
        "netns@${nsName}.service"
        "wireguard-tun0.service"
      ];
      serviceConfig = {
        NetworkNamespacePath = "/var/run/netns/${nsName}";
        # NetworkNamespacePath does not bind-mount /etc/netns/<name>/resolv.conf
        # like `ip netns exec` does, so provide Mullvad DNS explicitly.
        BindReadOnlyPaths = [
          "${pkgs.writeText "tunnel-socks-resolv.conf" "nameserver ${tunnelDns}"}:/etc/resolv.conf"
        ];
      };
    };

    # ── HTTP proxy inside the namespace ──────────────────────────

    services.tinyproxy = mkIf cfg.http.enable {
      enable = true;
      settings = {
        Listen = vethNsAddr;
        Port = cfg.http.port;
        MaxClients = 5000;
        Allow = [
          "127.0.0.1"
          "10.98.0.0/30"
        ];
      };
    };

    systemd.services.tinyproxy = mkIf cfg.http.enable {
      bindsTo = [ "netns@${nsName}.service" ];
      after = [
        "netns@${nsName}.service"
        "wireguard-tun0.service"
      ];
      serviceConfig = {
        NetworkNamespacePath = "/var/run/netns/${nsName}";
        LimitNOFILE = 16384;
        BindReadOnlyPaths = [
          "${pkgs.writeText "tunnel-http-resolv.conf" "nameserver ${tunnelDns}"}:/etc/resolv.conf"
        ];
      };
    };
  };
}
