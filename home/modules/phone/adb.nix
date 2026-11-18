# ADB and scrcpy, plus helpers that talk to the phone over Tailscale.
{ config, pkgs, ... }:

let
  addr = "${config.phone.host}:${toString config.phone.adbPort}";

  # Run once with the phone plugged in by USB: switches adbd to TCP mode.
  # Has to be repeated after every phone reboot.
  phoneAdbWifi = pkgs.writeShellApplication {
    name = "phone-adb-wifi";
    runtimeInputs = [ pkgs.android-tools pkgs.tailscale ];
    text = ''
      # Both ends must be on the tailnet for the phone hostname to resolve.
      tailscale up
      adb -d shell am broadcast -a com.tailscale.ipn.CONNECT_VPN -n com.tailscale.ipn/.IPNReceiver >/dev/null
      sleep 5

      adb -d tcpip ${toString config.phone.adbPort}
      sleep 2
      adb connect ${addr}
    '';
  };

  phoneScreen = pkgs.writeShellApplication {
    name = "phone-screen";
    runtimeInputs = [ pkgs.android-tools pkgs.scrcpy ];
    text = ''
      adb connect ${addr} >/dev/null
      exec scrcpy -s ${addr} --stay-awake --turn-screen-off "$@"
    '';
  };

  # Connects over the network, re-enabling TCP mode first if the phone is on USB,
  # then refreshes the status the Noctalia widget shows.
  phoneConnect = pkgs.writeShellApplication {
    name = "phone-connect";
    runtimeInputs = [ pkgs.android-tools pkgs.systemd phoneAdbWifi ];
    text = ''
      if [ "$(adb -d get-state 2>/dev/null)" = "device" ]; then
        phone-adb-wifi
      else
        adb connect ${addr}
      fi
      systemctl --user start phone-watch.service
    '';
  };

  phoneScreenshot = pkgs.writeShellApplication {
    name = "phone-screenshot";
    runtimeInputs = [ pkgs.android-tools pkgs.libnotify pkgs.coreutils ];
    text = ''
      dir="${config.home.homeDirectory}/Pictures/Phone"
      mkdir -p "$dir"
      file="$dir/phone-$(date +%Y%m%d-%H%M%S).png"
      adb -s ${addr} exec-out screencap -p > "$file"
      notify-send -a Phone -i phone "Phone screenshot saved" "$file"
      echo "$file"
    '';
  };

  # Android 13+ apps cannot switch Bluetooth themselves, so this goes through adb.
  # The phone app then reports the new state, which updates the Noctalia widget.
  phoneBluetooth = pkgs.writeShellApplication {
    name = "phone-bluetooth";
    runtimeInputs = [ pkgs.android-tools ];
    text = ''
      case "''${1:-}" in
        on) action=enable; state=STATE_ON ;;
        off) action=disable; state=STATE_OFF ;;
        *) echo "usage: phone-bluetooth on|off" >&2; exit 2 ;;
      esac
      adb connect ${addr} >/dev/null
      adb -s ${addr} shell cmd bluetooth_manager "$action"
      adb -s ${addr} shell cmd bluetooth_manager "wait-for-state:$state"
    '';
  };
in
{
  home.packages = [
    pkgs.android-tools
    pkgs.scrcpy
    phoneAdbWifi
    phoneScreen
    phoneConnect
    phoneScreenshot
    phoneBluetooth
  ];

  # Lets tools (and agents) target the phone without passing -s every time.
  home.sessionVariables.ANDROID_SERIAL = addr;
}
