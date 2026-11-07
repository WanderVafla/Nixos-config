# yazi as the file picker, through xdg-desktop-portal-termfilechooser (enabled in configuration.nix).
{ pkgs, lib, ... }:

let
  wrapper = "${pkgs.xdg-desktop-portal-termfilechooser}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh";
in
{
  # The portal runs as a systemd user service, which does not see the home-manager PATH,
  # so the terminal and yazi are given by full path.
  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${wrapper}
    default_dir=$HOME
    env=TERMCMD=${lib.getExe pkgs.kitty} --class termfilechooser
    env=PATH=${lib.makeBinPath [ pkgs.yazi ]}:/run/current-system/sw/bin
    open_mode=suggested
    save_mode=last
  '';

  programs.zen-browser.policies.Preferences."widget.use-xdg-desktop-portal.file-picker" = {
    Value = 1;
    Status = "default";
  };
}
