# Google Fonts that nixpkgs does not package on their own: Space Mono.
{ pkgs, ... }:

let
  # Pinned commit of github.com/google/fonts, so the files never change under the hashes.
  googleFontsRev = "7af0d90b4d532ffa4b041937b560c6df4e7b1e95";
  fontUrl = path: "https://raw.githubusercontent.com/google/fonts/${googleFontsRev}/ofl/${path}";

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
    cp ${spaceMonoRegular} $dir/SpaceMono-Regular.ttf
    cp ${spaceMonoBold} $dir/SpaceMono-Bold.ttf
  '';
in
{
  home.packages = [ googleFonts ];
}
