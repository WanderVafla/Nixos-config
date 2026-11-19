# "Doto Round": Doto frozen at its heaviest weight with round, slightly smaller dots, for clocks.
# Built from the local files/Doto.ttf by doto-round.py, with the Cyrillic of doto-cyrillic.txt
# added; a separate family name lets apps pick it
# directly, because most of them would otherwise render the thin Regular instance.
{ pkgs, ... }:

let
  # Values picked on the Doto Round bench (https://claude.ai/artifact/5oSrKMGJKNEhodtnQSD77d).
  # Size of each dot relative to the original Doto dot: smaller means wider gaps between dots.
  dotScale = "0.8";
  # Shape of the dots: 100 is round, 0 is square.
  roundness = "100";
  # Extra space after every character, in font units (a digit is 600 wide).
  tracking = "0";

  python = pkgs.python3.withPackages (p: [ p.fonttools ]);

  dotoRound = pkgs.runCommand "doto-round-font" { } ''
    mkdir -p $out/share/fonts/truetype/doto-round
    ${python}/bin/python3 -I ${./doto-round.py} ${./files/Doto.ttf} \
      $out/share/fonts/truetype/doto-round/DotoRound.ttf "Doto Round" \
      ${dotScale} ${roundness} ${tracking} ${./doto-cyrillic.txt}
  '';
in
{
  home.packages = [ dotoRound ];
}
