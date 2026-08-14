{ config, pkgs, inputs, lib, ... }:

let
  configPath = "/home/vladyslav/.config/nixos/home/modules/noctalia/config.toml";
  themeHyprlandPath = "/home/vladyslav/.config/nixos/home/modules/hypr/noctalia.lua";
in
{
  home.packages = [
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.brightnessctl
  ];

  xdg.configFile."noctalia/config.toml".source =
  config.lib.file.mkOutOfStoreSymlink configPath;

  xdg.configFile."hypr/nocatalia.lua".source =
  config.lib.file.mkOutOfStoreSymlink themeHyprlandPath;

  home.activation.makeNoctaliaConfigWritable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD chmod +w ${configPath}
      $DRY_RUN_CMD chmod +w ${themeHyprlandPath}
    '';
}
