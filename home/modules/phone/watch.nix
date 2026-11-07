# Periodically collects phone status that is available locally on the laptop,
# so it never wakes the phone: reachability from Tailscale's peer list and sync
# state from the Syncthing daemon. Sends desktop notifications (rendered by
# Noctalia) on connect and disconnect, and writes a key=value status file that
# the Noctalia phone widget reads. Battery data comes from the phone app instead
# (see notify.nix).
{ config, pkgs, ... }:

let
  phoneId = if config.phone.syncthingId == null then "" else config.phone.syncthingId;

  phoneWatch = pkgs.writeShellApplication {
    name = "phone-watch";
    runtimeInputs = with pkgs; [ tailscale libnotify gnugrep coreutils curl jq ];
    text = ''
      state_dir="''${XDG_RUNTIME_DIR:-/tmp}/phone-watch"
      mkdir -p "$state_dir"
      prev=$(cat "$state_dir/state" 2>/dev/null || echo offline)

      # Tailscale's own view of the peer: answered locally, no packet to the phone.
      peer_online=$(tailscale status --json 2>/dev/null \
        | jq -r --arg ip "${config.phone.host}" \
          '[.Peer[] | select(.TailscaleIPs | index($ip))][0].Online // false' || true)
      if [ "$peer_online" = true ]; then
        now=online
      else
        now=offline
      fi
      echo "$now" > "$state_dir/state"

      if [ "$now" != "$prev" ]; then
        if [ "$now" = online ]; then
          notify-send -a Phone "Phone connected" "Reachable over Tailscale at ${config.phone.host}"
        else
          notify-send -a Phone "Phone disconnected" "Not reachable over Tailscale"
        fi
      fi

      # Syncthing state comes from the local daemon as well.
      sync_connected=0
      sync_completion=""
      phone_id="${phoneId}"
      api_key=$(grep -o '<apikey>[^<]*' "${config.xdg.stateHome}/syncthing/config.xml" 2>/dev/null | cut -d'>' -f2 || true)
      if [ -n "$api_key" ] && [ -n "$phone_id" ]; then
        api() { curl -sf -m 3 -H "X-API-Key: $api_key" "http://127.0.0.1:8384/rest/$1" || true; }
        connected=$(api system/connections | jq -r --arg id "$phone_id" '.connections[$id].connected // false' || true)
        [ "$connected" = true ] && sync_connected=1
        sync_completion=$(api "db/completion?device=$phone_id" | jq -r '.completion // empty | floor' || true)
      fi

      cat > "$state_dir/status.tmp" <<EOF
      online=$([ "$now" = online ] && echo 1 || echo 0)
      low_battery=${toString config.phone.lowBattery}
      sync_connected=$sync_connected
      sync_completion=$sync_completion
      updated=$(date +%s)
      EOF
      mv "$state_dir/status.tmp" "$state_dir/status"
    '';
  };
in
{
  home.packages = [ phoneWatch ];

  systemd.user.services.phone-watch = {
    Unit.Description = "Collect phone status from Tailscale and Syncthing";
    Service = {
      Type = "oneshot";
      ExecStart = "${phoneWatch}/bin/phone-watch";
    };
  };

  systemd.user.timers.phone-watch = {
    Unit.Description = "Collect phone status every minute";
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
