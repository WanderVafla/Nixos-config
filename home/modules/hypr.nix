{ pkgs, ... }:

let
fullConfigLua = pkgs.writeText "hyprland-config.lua" ''
  ${builtins.readFile ./hypr/hyprland.lua}
  ${builtins.readFile ./hypr/look.lua}
  ${builtins.readFile ./hypr/binds.lua}
'';

hyprlandLua = (pkgs.replaceVarsWith {
    src = fullConfigLua;
    replacements = {
      fileManger = "dolphin";
      browser = "zen";
    };
  }).overrideAttrs (_: {
    checkPhase = ":";
  });
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    package = pkgs.hyprland;
    portalPackage = null;
    extraConfig = builtins.readFile hyprlandLua;
  };
}
