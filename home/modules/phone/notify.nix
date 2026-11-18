# phone-notify daemon: receives notifications, battery and media state from the
# phone app over Tailscale, shows them through Noctalia and publishes the phone's
# media session as the MPRIS player `phone`. Also runs the proximity lock
# (lock the laptop when the phone goes away, via Tailscale or a BLE beacon). The port is reachable only via tailscale0,
# which is the sole trusted firewall interface (see configuration.nix).
{ config, pkgs, lib, inputs, ... }:

let
  package = inputs.phone-notify.packages.${pkgs.stdenv.hostPlatform.system}.default;
  tokenFile = "${config.xdg.configHome}/phone-notify/token";

  # Sends a command to the phone app's command server, e.g. `phone-command dnd/off`.
  # Reads or sets the proximity lock mode through the local daemon:
  # `phone-lock-mode` prints it, `phone-lock-mode next|off|tailscale|bluetooth` sets it.
  phoneLockMode = pkgs.writeShellApplication {
    name = "phone-lock-mode";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      url="http://127.0.0.1:${toString config.phone.notifyPort}"
      auth="Authorization: Bearer $(cat ${tokenFile})"
      if [ $# -eq 1 ]; then
        curl -sf -m 5 -X POST -H "$auth" "$url/lock-mode/$1"
      fi
      curl -sf -m 5 -H "$auth" "$url/lock-mode"
      echo
    '';
  };

  phoneCommand = pkgs.writeShellApplication {
    name = "phone-command";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      if [ $# -ne 1 ]; then
        echo "usage: phone-command <path>   e.g. dnd/off, ringer/vibrate, media/next" >&2
        exit 2
      fi
      curl -sf -m 5 -X POST \
        -H "Authorization: Bearer $(cat ${tokenFile})" \
        "http://${config.phone.host}:${toString config.phone.mediaPort}/$1"
    '';
  };
in
{
  # The token is a secret, so it is generated on the machine and never stored in Nix.
  home.activation.phoneNotifyToken = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -s ${tokenFile} ]; then
      $DRY_RUN_CMD mkdir -p "$(dirname ${tokenFile})"
      $DRY_RUN_CMD sh -c '(umask 077; ${pkgs.openssl}/bin/openssl rand -hex 24 > ${tokenFile})'
    fi
  '';

  assertions = [
    {
      assertion = config.phone.proximityLock.scanTime < config.phone.proximityLock.interval;
      message = "phone.proximityLock.scanTime must be shorter than phone.proximityLock.interval.";
    }
  ];

  home.packages = [ phoneCommand phoneLockMode ];

  systemd.user.services.phone-notify = {
    Unit = {
      Description = "Show phone notifications on the desktop";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.getExe package;
      Environment = [
        "PHONE_NOTIFY_TOKEN_FILE=${tokenFile}"
        "PHONE_NOTIFY_LISTEN=0.0.0.0:${toString config.phone.notifyPort}"
        "PHONE_NOTIFY_LOW_BATTERY=${toString config.phone.lowBattery}"
        "PHONE_NOTIFY_PHONE_ADDRESS=${config.phone.host}:${toString config.phone.mediaPort}"
        "PHONE_NOTIFY_LOCK_MODE=${config.phone.proximityLock.mode}"
        "PHONE_NOTIFY_BT_RSSI=${toString config.phone.proximityLock.minRssi}"
        "PHONE_NOTIFY_LOCK_INTERVAL=${toString config.phone.proximityLock.interval}"
        "PHONE_NOTIFY_BT_SCAN_TIME=${toString config.phone.proximityLock.scanTime}"
        "PHONE_NOTIFY_LOCK_AWAY_CHECKS=${toString config.phone.proximityLock.awayChecks}"
        # Keeps ANDROID_SERIAL (host:adbPort) connected: after a phone reboot the
        # daemon finds the Wireless debugging port and runs `adb tcpip` through it.
        "PHONE_NOTIFY_ADB_PORT=${toString config.phone.adbPort}"
        # The proximity lock reads `tailscale status` and locks via `noctalia msg session lock`;
        # the ADB keeper runs `adb`.
        "PATH=${lib.makeBinPath [ pkgs.tailscale pkgs.noctalia pkgs.android-tools ]}"
      ];
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
