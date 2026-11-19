# Doto, a dot-matrix font for clocks and big numbers, installed from the copy kept in ./files.
# Source: github.com/google/fonts ofl/doto, licensed under the SIL Open Font License (files/Doto-OFL.txt).
{ pkgs, ... }:

let
  doto = pkgs.runCommand "doto-font" { } ''
    mkdir -p $out/share/fonts/truetype/doto $out/share/doc/doto
    cp ${./files/Doto.ttf} $out/share/fonts/truetype/doto/Doto.ttf
    cp ${./files/Doto-OFL.txt} $out/share/doc/doto/OFL.txt
  '';
in
{
  home.packages = [ doto ];
}
