{
  description = "NixOS Konfigurationen fuer Homelab VMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {

      base = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./modules/base.nix
          ./modules/hardware-vm.nix
          ./host-params.nix
        ];
      };

    };
  };
}
