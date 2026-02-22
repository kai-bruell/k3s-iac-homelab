# Host-spezifische Konfiguration: nixos-test
#
# Anpassen an die eigene Umgebung:
#   - networking.hostName
#   - systemd.network.networks."10-eth".networkConfig (IP, Gateway, DNS)
#   - users.users.root.openssh.authorizedKeys.keys
#
# WICHTIG: Die statische IP muss mit var.static_ip in terraform.tfvars uebereinstimmen,
#          damit Terraform nach dem Deploy weiss, wie die VM erreichbar ist.

{ ... }:

{
  networking = {
    hostName = "nixos-test";

    # systemd-networkd statt legacy networking
    # Vorteil: Interface-Name wird per Glob gematcht – kein Hardcoding von enp6s18 o.ae.
    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network = {
    enable = true;
    networks."10-eth" = {
      # Matcht alle Ethernet-Interfaces (ens*, enp*, eth*) – portabel bei jedem PCI-Slot
      matchConfig.Name = "en*";
      networkConfig = {
        Address = "192.168.178.180/24";
        Gateway = "192.168.178.199";
        DNS     = "192.168.178.199";
      };
    };
  };

  # SSH Public Keys fuer Root-Login (nur Keys, kein Passwort)
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEgXJQOJSsWyqpeFuiWJmLX8WBQ69PkAbaBwQ2LiowP9 homelab"
  ];
}
