# Host-spezifische Konfiguration: nixos-minimal
#
# Anpassen an die eigene Umgebung:
#   - networking.hostName
#   - systemd.network.networks."10-eth".networkConfig (IP, Gateway, DNS)
#   - users.users.root.openssh.authorizedKeys.keys
#
# WICHTIG: Die statische IP muss mit var.static_ip in terraform.tfvars uebereinstimmen,
#          damit Terraform nach dem Deploy weiss, wie die VM erreichbar ist.

{ modulesPath, ... }:

{
  networking = {
    hostName = "nixos-minimal";

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
        Address = "192.168.178.60/24"; # <- Anpassen
        Gateway = "192.168.178.1";     # <- Anpassen
        DNS     = "192.168.178.1";     # <- Anpassen
      };
    };
  };

  # SSH Public Keys fuer Root-Login (nur Keys, kein Passwort)
  users.users.root.openssh.authorizedKeys.keys = [
    # "ssh-ed25519 AAAA... user@host"
  ];
}
