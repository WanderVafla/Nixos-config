{ config, pkgs, inputs, lib, ... }:

let
  configPath = "/home/vladyslav/.config/nixos/home/modules/noctalia/config.toml";
  themeHyprlandPath = "/home/vladyslav/.config/nixos/home/modules/hypr/noctalia.lua";
in
{
  # home-manager.users.vladyslav = {
  #   imports = [
  #     inputs.noctalia.homeModules.default
  #   ];
  # };
  
  # home.packages = [
  #   inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
  #   pkgs.brightnessctl
  # ];

  xdg.configFile."noctalia/config.toml".source =
  config.lib.file.mkOutOfStoreSymlink configPath;

  xdg.configFile."hypr/noctalia.lua".source =
  config.lib.file.mkOutOfStoreSymlink themeHyprlandPath;

  home.activation.makeNoctaliaConfigWritable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD chmod +w ${configPath}
      $DRY_RUN_CMD chmod +w ${themeHyprlandPath}
    '';

    # configuration.nix
    
      # programs.noctalia = {
      #   enable = true;
      #   greeter = {
      #     enable = true;
      #     cursorTheme = {
      #       package = pkgs.bibata-cursors;
      #       name = "Bibata-Modern-Ice";
      #     };
      #     settings = {
      #       cursor.size = 24;
      #       keyboard.layout = "us";
      #       background = {
      #         color = "#000000";
      #         type = "color";
      #         # path = "${./path/to/wallpaper.png}";
      #       };
      #     };
      #   };
      # };
}