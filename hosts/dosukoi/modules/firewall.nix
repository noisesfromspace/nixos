{ ... }:
let
  hadouken = "10.10.0.6";
  tatsumaki = "10.10.0.3";
  dreame = "10.20.0.135";
in
{
  networking = {
    firewall.enable = false;
    useNetworkd = true;
    nftables = {
      enable = true;
      tables = {
        firewall = {
          family = "inet";
          content = # bash
            ''
              set blocklist_v4 {
                type ipv4_addr
                flags interval
              }

              chain input {
                # -10, before tailscale injections
                type filter hook input priority filter -10; policy drop;

                # --- BASELINE STATEFUL RULES ---
                ct state invalid drop;
                ct state established,related accept;

                iifname "peepee" ip saddr @blocklist_v4 drop comment "Drop traffic from WAN matching dynamic IPv4 blocklist";
                iifname "lo" accept;

                # --- SERVICES ---
                iifname { "peepee", "lan", "wifi", "opt1" } udp dport 51820 accept comment "Wireguard setup connections";
                iifname { "peepee", "lan", "wifi", "opt1" } udp dport 41641 accept comment "Tailscale setup connections";

                iifname { "opt1", "tailscale0" } tcp dport 22 ct state new limit rate 10/minute accept comment "Allow SSH management";
                iifname { "lan", "wifi", "opt1" } udp dport 67 accept comment "DHCP";

                iifname { "tailscale0" } tcp dport { 80, 443, 4443 } accept comment "Websites hosted on router";
                iifname { "tailscale0" } tcp dport { 9009, 9010, 9011, 9012, 9013 } accept comment "Croc relay";
                iifname { "tailscale0", "lan", "wifi", "opt1" } udp dport 53 accept comment "DNS";
                iifname { "tailscale0", "lan", "wifi", "opt1" } tcp dport 53 accept comment "DNS";

                # Allow IPv6 Neighbor Discovery and Ping 
                iifname { "lan", "wifi", "tailscale0", "opt1" } icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, echo-request } accept;

                # --- ISP SERVICE RULES (WAN) ---
                iifname "peepee" udp sport 547 udp dport 546 accept comment "DHCPv6 client-server communication";
                iifname "peepee" icmpv6 type { echo-reply, destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept comment "Essential IPv6 ICMP for discovery, MTU, etc.";
                iifname "peepee" icmp type { destination-unreachable, time-exceeded, parameter-problem } accept comment "Essential IPv4 ICMP for Path MTU Discovery";
                iifname "peepee" icmp type echo-request limit rate 2/second accept comment "Rate-limited IPv4 ping responses";
              }

              chain forward {
                # -10, before tailscale injections
                type filter hook forward priority filter -10; policy drop;

                # --- BASELINE STATEFUL FORWARDING ---
                ct state invalid drop;
                ct state established,related accept;

                # Essential for HTTPS/Curl (Path MTU Discovery)
                meta l4proto ipv6-icmp icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, echo-request, echo-reply } accept;

                iifname "peepee" ip saddr @blocklist_v4 drop comment "Drop forwarded traffic from WAN matching dynamic IPv4 blocklist";
                oifname "peepee" tcp flags syn tcp option maxseg size set rt mtu;

                # --- INBOUND PORT FORWARDING RULES ---
                iifname "peepee" oifname "lan" ip daddr ${hadouken} meta l4proto { tcp, udp } th dport 22000 ct state new accept comment "Syncthing IPv4";
                iifname "peepee" oifname "lan" ip daddr ${tatsumaki} tcp dport 8333 ct state new accept comment "Bitcoin";

                # --- GRANULAR INTER-LAN FORWARDING ---
                iifname { "opt1" } oifname { "lan", "opt1", "wifi" } accept comment "opt1 free to do anything";
                iifname { "lan", "wifi", "opt1" } oifname { "lan", "wifi", "opt1" } udp dport 41641 accept comment "Allow Tailscale";
                iifname "lan" oifname "wifi" tcp dport { 80, 443 } accept comment "Allow LAN to access IoT device web UIs on WiFi";

                # --- IOT RESTRICTIONS ---
                iifname { "lan", "wifi" } oifname "wifi" ip daddr ${dreame} ct state new accept comment "Allow LAN/WiFi to access Dreame";
                iifname "wifi" ip saddr ${dreame} oifname "peepee" meta hour "10:00"-"19:00" accept comment "Dreame Internet Access Window";
                iifname "wifi" ip saddr ${dreame} oifname "peepee" drop comment "Block Dreame Internet outside schedule";

                # --- INTERNET EGRESS RULES ---
                iifname { "lan", "wifi", "opt1", "tailscale0", "wg0" } oifname "peepee" accept;

                # --- TAILSCALE SUBNET ROUTING ---
                iifname { "lan", "wifi", "opt1" } oifname "tailscale0" accept;
                iifname "tailscale0" oifname { "lan", "wifi", "opt1" } accept;
              }
            '';
        };

        nat = {
          family = "ip";
          content = ''
            chain prerouting {
              type nat hook prerouting priority dstnat; policy accept;

              # --- DNS REDIRECTION ---
              # iifname "wifi" ip saddr ${dreame} meta l4proto { tcp, udp } th dport 53 dnat to 10.20.0.1 comment "Force Dreame to use router DNS";

              # --- IPV4 PORT FORWARDING (DNAT) ---
              iifname "peepee" tcp dport 22000 dnat to ${hadouken};
              iifname "peepee" udp dport 22000 dnat to ${hadouken};
              iifname "peepee" tcp dport 8333 dnat to ${tatsumaki};
            }

            chain postrouting {
              type nat hook postrouting priority srcnat; policy accept;

              # --- OUTBOUND IPV4 NAT ---
              oifname "peepee" masquerade;
            }
          '';
        };
      };
    };
  };
}
