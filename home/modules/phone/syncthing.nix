# Two-way file sync between ~/Phone and the phone via Syncthing.
{ config, lib, ... }:

let
  id = config.phone.syncthingId;
in
{
  services.syncthing = {
    enable = true;
    # Devices and folders come only from this file; GUI changes are reverted.
    overrideDevices = true;
    overrideFolders = true;

    settings = {
      options.urAccepted = -1;

      devices = lib.optionalAttrs (id != null) {
        phone = {
          inherit id;
          addresses = [ "tcp://${config.phone.host}:22000" "dynamic" ];
        };
      };

      folders = lib.optionalAttrs (id != null) {
        phone = {
          label = "Phone";
          path = "${config.home.homeDirectory}/Phone";
          devices = [ "phone" ];
        };
      };
    };
  };
}
