{ pkgs, ... }:

let
  activeCursorTheme = "Quintom_Ink";
  cursorPackage = pkgs.quintom-cursor-theme;
  cursorSize = 24;
in
{
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    hyprcursor.enable = true;

    package = cursorPackage;
    name = activeCursorTheme;
    size = cursorSize;
  };
}