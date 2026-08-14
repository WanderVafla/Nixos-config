{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    package = pkgs.kitty;
    settings = {
      confirm_os_window_close = 0;
    };
    extraConfig = ''
      include themes/noctalia.conf
    '';
  };
}