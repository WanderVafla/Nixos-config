# "Dot Clock": our own 5x9 dot-matrix font for clocks, built from the grids in glyphs.txt.
# It only has digits, ":", ".", "-", "/" and space. Tune it on the Doto Round bench
# (https://claude.ai/artifact/5oSrKMGJKNEhodtnQSD77d), then put the values here.
{ pkgs, ... }:

let
  # Dot diameter relative to a grid cell: 1.0 makes neighbouring dots touch.
  dotScale = "1.0";
  # Extra space after every character, in font units (a grid cell is 100).
  tracking = "-100";

  python = pkgs.python3.withPackages (p: [ p.fonttools ]);

  dotClock = pkgs.runCommand "dot-clock-font" { } ''
    mkdir -p $out/share/fonts/truetype/dot-clock
    ${python}/bin/python3 -I ${./build.py} ${./glyphs.txt} \
      $out/share/fonts/truetype/dot-clock/DotClock.ttf "Dot Clock" \
      ${dotScale} ${tracking}
  '';
in
{
  home.packages = [ dotClock ];
}
