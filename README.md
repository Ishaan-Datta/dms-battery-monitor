# Bluetooth Battery Monitor for DMS

A [DankMaterialShell](https://danklinux.com/docs/dankmaterialshell/plugin-development)
plugin that monitors selected Bluetooth devices, displays their battery levels
in DankBar, and sends low-battery notifications.

## Features

- One headphone icon and battery percentage per available device
- BlueZ aliases used automatically as notification names
- Per-device warning and critical thresholds
- Per-device notification reminder cooldowns
- Configurable polling interval
- Immediate refresh with short retries when a configured device connects
- Normal and critical notification urgency
- Persisted notification state to avoid duplicate alerts after a DMS restart
- Horizontal and vertical DankBar support

## Requirements

- DankMaterialShell 1.6 or newer
- `bluetoothctl` from BlueZ
- `notify-send` from libnotify
- A paired Bluetooth device that exposes battery data through BlueZ

Check whether BlueZ exposes a battery reading with:

```console
bluetoothctl info AA:BB:CC:DD:EE:FF
```

The output must contain `Connected: yes` and a `Battery Percentage` field.

## Nix installation

Add this repository as a flake input and pass its package to the official DMS
Home Manager module:

```nix
{
  inputs.dms-battery-monitor.url = "github:Ishaan-Datta/dms-battery-monitor";

  outputs = inputs@{ nixpkgs, ... }: {
    homeConfigurations.your-user = inputs.home-manager.lib.homeManagerConfiguration {
      # ...
      modules = [
        inputs.dms.homeModules.default
        ({ pkgs, ... }: {
          home.packages = with pkgs; [
            bluez
            libnotify
          ];

          programs.dank-material-shell.plugins.dmsBluetoothBatteryMonitor = {
            enable = true;
            src = inputs.dms-battery-monitor.packages.${pkgs.system}.default;
          };
        })
      ];
    };
  };
}
```

## Configuration

Polling interval, Bluetooth MAC address, wwwarning/critical thresholds and reminder cooldown are all configured under the plugin settings file (`~/.config/DankMaterialShell/plugin_settings.json`), see an example configuration in `plugin_settings.example.json`.
