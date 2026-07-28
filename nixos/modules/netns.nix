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

  mullvadEndpointIP = "169.150.196.15";
  mullvadEndpoint = "${mullvadEndpointIP}:51820";
  mullvadPublicKey = "BChJDLOwZu9Q1oH0UcrxcHP6xxHhyRbjrBUsE0e07Vk=";
  mullvadAddress = "10.64.205.236/32";
  mullvadDns = "10.64.0.1";

  nsName = "tunnel";
  bridgeName = "${nsName}-br";
  vethHost = "veth-${nsName}";
  vethNs = "veth-ns";
  fwMark = "42";

  # setns wrapper enters the tunnel namespace then drops privileges.
  # security.wrappers gives it CAP_SYS_ADMIN so any user can use it without sudo.
  tunnel-exe =
    pkgs.runCommandCC "tunnel-nsenter"
      {
        src = pkgs.writeText "tunnel.c" /* c */ ''
          #define _GNU_SOURCE
          #include <fcntl.h>
          #include <sched.h>
          #include <sys/types.h>
          #include <unistd.h>
          int main(int argc, char **argv) {
              if (argc < 2) return 1;
              int fd = open("/var/run/netns/${nsName}", O_RDONLY | O_CLOEXEC);
              if (fd < 0) return 1;
              if (setns(fd, CLONE_NEWNET)) { close(fd); return 2; }
              close(fd);
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
        $CC -O2 -o $out/bin/tunnel $src
      '';
in
{
  options.hosts.netns = {
    enable = mkEnableOption "Mullvad VPN network namespace — isolates traffic through Mullvad WireGuard";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ tunnel-exe ];

    security.wrappers.tunnel = {
      source = "${tunnel-exe}/bin/tunnel";
      capabilities = "cap_sys_admin+ep";
      owner = "root";
      group = "root";
    };

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
      fwMark = fwMark;
      peers = [
        {
          name = "mullvad";
          publicKey = mullvadPublicKey;
          endpoint = mullvadEndpoint;
          allowedIPs = [ "0.0.0.0/0" ];
          persistentKeepalive = 25;
        }
      ];

      # Runs before the WG interface is created — sets up the veth pair
      # and a temporary default route so the WG-encrypted packets can
      # reach Mullvad's endpoint through the host's internet.
      preSetup = ''
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
        ip -n ${nsName} route add default via ${vethHostAddr}
      '';

      # Runs after the WG interface is created. Configures the peer,
      # waits for the handshake, fixes routing, and applies NAT +
      # kill-switch firewall rules.
      postSetup = ''
        NS="ip netns exec ${nsName}"

        # DNS — /etc/netns/<name>/ is bind-mounted over /etc/resolv.conf
        # for any process that enters the namespace via `ip netns exec`.
        mkdir -p /etc/netns/${nsName}
        echo "nameserver ${mullvadDns}" > /etc/netns/${nsName}/resolv.conf

        # WireGuard peer + wait for handshake
        $NS wg set tun0 peer ${mullvadPublicKey} \
          endpoint ${mullvadEndpoint} \
          allowed-ips 0.0.0.0/0 \
          persistent-keepalive 25

        for i in $(seq 1 15); do
          HS=$($NS wg show tun0 latest-handshakes | awk '{print $2}')
          if [[ -n $HS && $HS != "0" ]]; then break; fi
          sleep 1
        done

        # Swap routing: endpoint via veth (so WG encrypted packets
        # can reach Mullvad's server), everything else via tun0.
        ip -n ${nsName} route del default via ${vethHostAddr}
        ip -n ${nsName} route add ${mullvadEndpointIP} via ${vethHostAddr}
        ip -n ${nsName} route add default dev tun0

        # NAT — masquerade namespace traffic to the internet
        nft delete table ip tunnel-nat 2>/dev/null || true
        nft add table ip tunnel-nat
        nft 'add chain ip tunnel-nat postrouting { type nat hook postrouting priority srcnat; }'
        nft 'add chain ip tunnel-nat forward { type filter hook forward priority filter; }'
        nft add rule ip tunnel-nat postrouting ip saddr 10.98.0.0/30 masquerade
        nft add rule ip tunnel-nat forward iifname ${bridgeName} accept
        nft add rule ip tunnel-nat forward oifname ${bridgeName} accept

        # Kill switch inside the namespace — default deny, only allow
        # WG-marked encrypted packets through the veth and all traffic
        # through the WG tunnel interface.
        $NS nft delete table inet tunnel-fw 2>/dev/null || true
        $NS nft add table inet tunnel-fw

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

        # All other outbound traffic must go through the WG tunnel
        $NS nft add rule inet tunnel-fw output oif tun0 accept

        # Catch any DNS that somehow tries to bypass the tunnel
        $NS nft add rule inet tunnel-fw output \
          oif ${vethNs} meta l4proto { tcp, udp } th dport 53 drop
      '';

      preShutdown = ''
        # Clean up host-side NAT table. The in-namespace tunnel-fw
        # table dies automatically when the namespace is deleted.
        nft delete table ip tunnel-nat 2>/dev/null || true
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
  };
}
