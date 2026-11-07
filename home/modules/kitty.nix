{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    package = pkgs.kitty;
    settings = {
      confirm_os_window_close = 0;
      enable_audio_bell = false;
      window_padding_width = 3;
      background_opacity = "0.9";
      cursor_shape = "beam";
      hide_window_decorations = "yes";
      tab_bar_style = "powerline";
    };
    extraConfig = ''
      include themes/noctalia.conf
    '';
  };
}