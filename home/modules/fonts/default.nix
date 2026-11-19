# All user fonts, installed through home-manager and made visible to fontconfig.
{ pkgs, ... }:

{
  imports = [
    ./doto.nix
    ./doto-round.nix
    ./google-fonts.nix
  ];

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    font-awesome_4
    dejavu_fonts
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
  ];
}
