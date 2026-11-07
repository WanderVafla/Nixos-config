# phone-notify daemon: receives notifications from the phone app over Tailscale
# and shows them through Noctalia. The port is reachable only via tailscale0,
# which is the sole trusted firewall interface (see configuration.nix).
{ config, pkgs, lib, inputs, ... }:

let
  package = inputs.phone-notify.packages.${pkgs.stdenv.hostPlatform.system}.default;
  tokenFile = "${config.xdg.configHome}/phone-notify/token";
in
{
  # The token is a secret, so it is generated on the machine and never stored in Nix.
  home.activation.phoneNotifyToken = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -s ${tokenFile} ]; then
      $DRY_RUN_CMD mkdir -p "$(dirname ${tokenFile})"
      $DRY_RUN_CMD sh -c '(umask 077; ${pkgs.openssl}/bin/openssl rand -hex 24 > ${tokenFile})'
    fi
  '';

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
      ];
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
