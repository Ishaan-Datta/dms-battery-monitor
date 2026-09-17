{
  description = "Bluetooth battery monitor plugin for DankMaterialShell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          plugin = pkgs.stdenvNoCC.mkDerivation {
            pname = "dms-plugin-bluetooth-battery-monitor";
            version = "1.0.0";
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [
                ./BluetoothBatteryDaemon.qml
                ./BluetoothBatterySettings.qml
                ./BluetoothBatteryWidget.qml
                ./StartupCheck.qml
                ./plugin.json
              ];
            };

            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              runHook preInstall
              mkdir -p "$out"
              cp \
                BluetoothBatteryDaemon.qml \
                BluetoothBatterySettings.qml \
                BluetoothBatteryWidget.qml \
                StartupCheck.qml \
                plugin.json \
                "$out/"
              runHook postInstall
            '';

            meta = {
              description = "Monitor Bluetooth device batteries in DankBar";
              license = pkgs.lib.licenses.mit;
              platforms = pkgs.lib.platforms.linux;
            };
          };
        in
        {
          default = plugin;
          dmsBluetoothBatteryMonitor = plugin;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          package = self.packages.${system}.default;
          manifest =
            pkgs.runCommand "check-dms-bluetooth-battery-monitor-manifest"
              {
                nativeBuildInputs = [ pkgs.jq ];
              }
              ''
                jq -e '
                  .id == "dmsBluetoothBatteryMonitor" and
                  .type == "composite" and
                  .components.daemon == "./BluetoothBatteryDaemon.qml" and
                  .components.widget == "./BluetoothBatteryWidget.qml" and
                  .settings == "./BluetoothBatterySettings.qml" and
                  .startupCheck == "./StartupCheck.qml"
                ' ${./plugin.json} >/dev/null

                test -f ${./BluetoothBatteryDaemon.qml}
                test -f ${./BluetoothBatterySettings.qml}
                test -f ${./BluetoothBatteryWidget.qml}
                test -f ${./StartupCheck.qml}
                touch "$out"
              '';
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              check-jsonschema
              jq
              nixfmt
            ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
