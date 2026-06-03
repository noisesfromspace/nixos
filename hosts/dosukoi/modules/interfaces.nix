# https://www.sput.nl/internet/freedom/config.html
# https://s-n.me/building-a-nixos-router-for-a-uk-fttp-isp-the-basics
# https://www.jjpdev.com/posts/home-router-nixos/
{ pkgs, ... }:
{
  services.pppd = {
    enable = true;
    peers = {
      peepee = {
        enable = true;
        autostart = true;
        config = ''
          # Standard PPPoE plugin over the 'wan6' VLAN interface
          plugin pppoe.so wan6

          # Interface name for the PPPoE link
          ifname peepee

          name "fake@freedom.nl"
          password "1234"

          # Automatically set the default IPv4 route via this link
          defaultroute
          # No authentication needed for this ISP
          noauth

          # Enable IPv6 negotiation on the link
          +ipv6
          # Use the link-local address for IPv6 routing
          ipv6cp-use-ipaddr

          # Send keepalive every 10 seconds, after 6 failing reconnect
          lcp-echo-interval 10
          lcp-echo-failure 6

          # Keep the connection alive
          persist
          # Retry indefinitely if connection fails
          maxfail 0

          # Negotiate a full 1500-byte MTU for the IP packets on the PPPoE link.
          mtu 1500
          mru 1500
        '';
      };
    };
  };

  # Disable harderning for ip-forwarding
  nix-mineral.settings.network.ip-forwarding = true;

  systemd.services.qos-cake-wan = {
    description = "Apply and maintain CAKE queue discipline for peepee (WAN)";

    requires = [ "sys-subsystem-net-devices-peepee.device" ];
    after = [ "sys-subsystem-net-devices-peepee.device" ];
    bindsTo = [ "sys-subsystem-net-devices-peepee.device" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      ExecStart = pkgs.writeShellScript "start-cake-idempotent" ''
        #!${pkgs.runtimeShell}
        set -e
        ${pkgs.ethtool}/bin/ethtool -K peepee gso off tso off gro off
        ${pkgs.iproute2}/bin/tc qdisc replace dev peepee root cake \
            bandwidth 950Mbit \
            rtt 30ms \
            nat \
            overhead 12 \
            diffserv4 \
            no-ack-filter
      '';
      ExecStop = "${pkgs.iproute2}/bin/tc qdisc del dev peepee root";
    };
  };
  systemd.network = {
    wait-online.enable = false; # PPPoE handles the 'online' state.

    links = {
      "10-wan" = {
        matchConfig.MACAddress = "64:62:66:2f:37:ba";
        linkConfig.Name = "wan";
      };
      "20-lan" = {
        matchConfig.MACAddress = "64:62:66:2f:37:bc";
        linkConfig.Name = "lan";
      };
      "30-wifi" = {
        matchConfig.MACAddress = "64:62:66:2f:37:bd";
        linkConfig.Name = "wifi";
      };
      "40-opt1" = {
        matchConfig.MACAddress = "64:62:66:2f:37:bb";
        linkConfig.Name = "opt1";
      };
    };

    netdevs = {
      "10-wan6" = {
        netdevConfig = {
          Name = "wan6";
          Kind = "vlan";
        };
        vlanConfig = {
          Id = 6;
        };
      };
    };

    networks = {
      "10-wan" = {
        matchConfig.Name = "wan";
        linkConfig.MTUBytes = "1508";
        networkConfig = {
          VLAN = [ "wan6" ];
        };
      };

      "11-wan6" = {
        matchConfig.Name = "wan6";
        linkConfig.RequiredForOnline = "no";
      };

      "15-peepee" = {
        matchConfig.Name = "peepee";
        networkConfig = {
          DHCP = "ipv6";
          IPv6AcceptRA = true;
          ConfigureWithoutCarrier = "yes";
        };
        linkConfig.RequiredForOnline = "yes";

        ipv6AcceptRAConfig = {
          DHCPv6Client = true;
        };
        dhcpV6Config = {
          UseDelegatedPrefix = true; # Request a prefix for our LANs.
          UseAddress = false; # Don't assign an address to this interface.
          WithoutRA = "solicit"; # Start soliciting immediately (ISP sends no RAs).
        };
        routes = [
          {
            Gateway = "::";
            GatewayOnLink = true;
          }
        ];
      };

      "20-lan" = {
        matchConfig.Name = "lan";
        address = [ "10.10.0.1/23" ];
        networkConfig = {
          DHCPServer = "yes";
          IPv6SendRA = "yes";
          DHCPPrefixDelegation = "yes";
        };
        dhcpServerConfig = {
          PoolOffset = 100;
          PoolSize = 20;
        };
        dhcpPrefixDelegationConfig = {
          SubnetId = "0xc0de";
        };
      };

      "21-wifi" = {
        matchConfig.Name = "wifi";
        address = [ "10.20.0.1/24" ];
        networkConfig = {
          DHCPServer = "yes";
          IPv6SendRA = "yes";
          DHCPPrefixDelegation = "yes";
        };
        dhcpServerConfig.PoolOffset = 10;
        dhcpServerStaticLeases = [
          {
            Address = "10.20.0.130"; # shelly
            MACAddress = "FC:B4:67:25:45:34";
          }
          {
            Address = "10.20.0.131"; # shelly
            MACAddress = "E8:6B:EA:EA:12:F4";
          }
          {
            Address = "10.20.0.132"; # shelly
            MACAddress = "E4:65:B8:47:75:F4";
          }
          {
            Address = "10.20.0.133"; # shelly
            MACAddress = "30:C9:22:87:0B:EC";
          }
          {
            Address = "10.20.0.134"; # shelly
            MACAddress = "08:F9:E0:FC:7A:90";
          }
          {
            Address = "10.20.0.135"; # vacuum
            MACAddress = "00:AE:F7:0A:7E:7A";
          }
        ];
        dhcpPrefixDelegationConfig = {
          SubnetId = "0xbeef";
        };
      };

      "22-opt1" = {
        matchConfig.Name = "opt1";
        address = [ "10.30.0.1/24" ];
        networkConfig = {
          DHCPServer = "yes";
          IPv6SendRA = "yes";
          DHCPPrefixDelegation = "yes";
        };
        dhcpPrefixDelegationConfig = {
          SubnetId = "0xb00f";
        };
      };
    };
  };
}
