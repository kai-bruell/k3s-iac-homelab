{
  description = "NixOS Konfigurationen fuer Homelab VMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    # Deklaratives Disk-Layout (ersetzt Shell-Script + hardware-vm.nix fileSystems)
    # https://github.com/nix-community/disko
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko }: {
    nixosConfigurations = {

      # Minimale NixOS-VM fuer Proxmox
      # Dient als Dokumentation und Basis-Template fuer weitere VMs
      # Deploy: tofu apply (via nixos-anywhere, kein Packer noetig)
      nixos-minimal = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./modules/base.nix
          ./modules/hardware-vm.nix
          ./hosts/nixos-minimal/default.nix
          ./hosts/nixos-minimal/disko.nix
        ];
      };

      # Beispiel-VM als Basis-Template fuer weitere VMs
      # Deploy: tofu apply (via nixos-anywhere, kein Packer noetig)
      nixos-example = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./modules/base.nix
          ./modules/hardware-vm.nix
          ./hosts/nixos-example/default.nix
          ./hosts/nixos-example/disko.nix
        ];
      };

    };
  };
}
