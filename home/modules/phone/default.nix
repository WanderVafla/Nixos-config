# Integration with the phone (Nothing Phone 3): ADB over Tailscale, scrcpy,
# Syncthing, and notifications plus battery pushed by the phone-notify app,
# all shown in Noctalia.
{ lib, ... }:

{
  imports = [
    ./adb.nix
    ./syncthing.nix
    ./watch.nix
    ./notify.nix
  ];

  options.phone = {
    host = lib.mkOption {
      type = lib.types.str;
      # Tailscale IP rather than the MagicDNS name: it is stable and keeps
      # working even when Tailscale DNS is turned off.
      default = "100.79.194.71";
      description = "Tailscale IP or hostname of the phone.";
    };

    adbPort = lib.mkOption {
      type = lib.types.port;
      default = 5555;
      description = "Port adbd listens on after `adb tcpip`.";
    };

    syncthingId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "FJG4XHR-EKX52G3-6JT6R5F-ADGTGVM-HOFSLYN-WVY5XR2-MV3MZ5Q-AF5NMAN";
      description = "Syncthing device ID of the phone; folder sharing is skipped while null.";
    };

    lowBattery = lib.mkOption {
      type = lib.types.ints.between 1 100;
      default = 20;
      description = "Battery percentage below which a notification is sent.";
    };

    notifyPort = lib.mkOption {
      type = lib.types.port;
      default = 47100;
      description = "Port the phone-notify daemon listens on for the phone app.";
    };

    proximityLock = {
      mode = lib.mkOption {
        type = lib.types.enum [ "off" "tailscale" "bluetooth" ];
        default = "off";
        description = ''
          Default way to detect that the phone went away and lock the laptop.
          Only used until a mode is picked in Noctalia or the phone's tile;
          that choice is saved in ~/.local/state/phone-notify/lock-mode.
        '';
      };

      minRssi = lib.mkOption {
        type = lib.types.ints.between (-100) 0;
        default = -75;
        description = "Weakest BLE beacon signal, in dBm, that still counts as near (Bluetooth mode).";
      };

      interval = lib.mkOption {
        type = lib.types.ints.positive;
        default = 15;
        description = "Seconds from the start of one proximity check to the start of the next.";
      };

      scanTime = lib.mkOption {
        type = lib.types.ints.positive;
        default = 6;
        description = ''
          Seconds each Bluetooth check scans for the beacon. The laptop's radio is
          busy scanTime / interval of the time (6 / 15 = 40 %).
        '';
      };

      awayChecks = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3;
        description = "Consecutive \"away\" checks before locking; lock delay ≈ interval × awayChecks.";
      };
    };

    mediaPort = lib.mkOption {
      type = lib.types.port;
      default = 47101;
      description = "Port of the phone app's command server (media controls); fixed in CommandServer.kt.";
    };
  };
}
