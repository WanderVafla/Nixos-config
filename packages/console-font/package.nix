# Console (PSF) version of a fontconfig font family, for the Linux VT and dot-greeter.
# Glyphs the family lacks come from Terminus.
{
  lib,
  runCommand,
  python3,
  fontconfig,
  makeFontsConf,
  terminus_font,
  # Fontconfig family name, e.g. "DejaVu Sans Mono". It has to be monospaced.
  family,
  # Font packages to look the family up in.
  fontPackages,
}:

let
  python = python3.withPackages (p: [
    p.fonttools
    p.pillow
  ]);
in
runCommand "console-font-${lib.strings.sanitizeDerivationName family}"
  {
    nativeBuildInputs = [
      fontconfig
      python
    ];
    FONTCONFIG_FILE = makeFontsConf { fontDirectories = fontPackages; };
  }
  ''
    export HOME=$TMPDIR
    found=$(fc-match --format='%{family}' ${lib.escapeShellArg family})
    # fc-match silently falls back to another family when the name is unknown.
    case ",$found," in
      *",${family},"*) ;;
      *) echo "font family '${family}' not found in fontPackages (fc-match gave '$found')" >&2; exit 1 ;;
    esac
    file=$(fc-match --format='%{file}' ${lib.escapeShellArg family})
    mkdir -p $out/share/consolefonts
    python3 -I ${./ttf2psf.py} "$file" \
      ${terminus_font}/share/consolefonts/ter-v32n.psf.gz \
      $out/share/consolefonts/console.psf
  ''
