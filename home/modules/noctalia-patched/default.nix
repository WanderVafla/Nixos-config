# Noctalia with local patches, installed instead of the plain nixpkgs package.
# - toast-dot.patch: a notification without its own image shows a red dot instead of a bell,
#   matching the dot-notify bar widget.
# Drop a patch here when it no longer applies after a Noctalia update.
{ pkgs, ... }:

let
  noctalia = pkgs.noctalia.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./toast-dot.patch ];
  });
in
{
  home.packages = [ noctalia ];
}
