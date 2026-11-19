# Google Fonts that nixpkgs does not package on their own:
# Doto (dot matrix, for clocks and big numbers) and Space Mono.
{ pkgs, ... }:

let
  # Pinned commit of github.com/google/fonts, so the files never change under the hashes.
  googleFontsRev = "7af0d90b4d532ffa4b041937b560c6df4e7b1e95";
  fontUrl = path: "https://raw.githubusercontent.com/google/fonts/${googleFontsRev}/ofl/${path}";

  doto = pkgs.fetchurl {
    name = "Doto.ttf";
    url = fontUrl "doto/Doto%5BROND%2Cwght%5D.ttf";
    sha256 = "09nl6w1r2d01a7k8djc8bmlwkqfvwb6q9aldd7rivfakg39yfkvg";
  };
  spaceMonoRegular = pkgs.fetchurl {
    url = fontUrl "spacemono/SpaceMono-Regular.ttf";
    sha256 = "064f7j9xypjv0vvlzf66fldhlzrm53dlhxwg6s1xmsmf5cc7x0wm";
  };
  spaceMonoBold = pkgs.fetchurl {
    url = fontUrl "spacemono/SpaceMono-Bold.ttf";
    sha256 = "0ncwb4g8c3i63i13apr5ivrmdjgmd8r6l86fxw35jzpv3ba76pj0";
  };

  googleFonts = pkgs.runCommand "google-fonts-extra" { } ''
    dir=$out/share/fonts/truetype/google-fonts-extra
    mkdir -p $dir
    cp ${doto} $dir/Doto.ttf
    cp ${spaceMonoRegular} $dir/SpaceMono-Regular.ttf
    cp ${spaceMonoBold} $dir/SpaceMono-Bold.ttf
  '';
in
{
  home.packages = [ googleFonts ];
}
