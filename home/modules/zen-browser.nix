{ config, pkgs, lib, ... }:

let
  cacheDir = config.home.homeDirectory;
in
{
  home.activation.linkNoctaliaZenTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for dir in ${cacheDir}/.config/zen/*/; do
      base=$(basename "$dir")
      case "$base" in
        firefox-mpris|Profile\ Groups) continue ;;
      esac
      [ ! -d "$dir/chrome" ] && $DRY_RUN_CMD mkdir -p "$dir/chrome"
      for f in userChrome userContent; do
        src="${cacheDir}/.cache/noctalia/zen-''${f}.css"
        if [ -f "$src" ]; then
          $DRY_RUN_CMD ln -sf "$src" "$dir/chrome/''${f}.css"
        fi
      done
    done
  '';
}
