# Two-way file sync with the phone via Syncthing: ~/Phone and the Obsidian vault.
{ config, lib, ... }:

let
  id = config.phone.syncthingId;
  vault = "Documents/Valut/SyncLive";
in
{
  # Per-device Obsidian state that would conflict on every switch between
  # laptop and phone. Syncthing never syncs .stignore itself.
  home.file."${vault}/.stignore" = lib.mkIf (id != null) {
    text = ''
      .obsidian/workspace.json
      .obsidian/workspace-mobile.json
      .obsidian/workspaces.json
      .trash
    '';
  };

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

        # The ID must match the folder already created on the phone.
        obsidian-synclive = {
          label = "Obsidian SyncLive";
          path = "${config.home.homeDirectory}/${vault}";
          devices = [ "phone" ];
        };
      };
    };
  };
}
