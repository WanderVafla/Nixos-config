# "Doto Round": Doto frozen at its heaviest weight with round dots, a dot-matrix look for clocks.
# Built from the local files/Doto.ttf by doto-round.py; a separate family name lets apps pick it
# directly, because most of them would otherwise render the thin Regular instance.
{ pkgs, ... }:

let
  python = pkgs.python3.withPackages (p: [ p.fonttools ]);

  dotoRound = pkgs.runCommand "doto-round-font" { } ''
    mkdir -p $out/share/fonts/truetype/doto-round
    ${python}/bin/python3 -I ${./doto-round.py} ${./files/Doto.ttf} \
      $out/share/fonts/truetype/doto-round/DotoRound.ttf "Doto Round"
  '';
in
{
  home.packages = [ dotoRound ];
}
