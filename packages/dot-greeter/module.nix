# NixOS module: greetd with the dot-greeter console login screen, and a console font made from
# a fontconfig family. The build fails if a character the greeter draws is not in that font.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.dot-greeter;
  inherit (lib) mkOption types;

  colorNames = [
    "black"
    "dark-red"
    "dark-green"
    "dark-yellow"
    "dark-blue"
    "dark-magenta"
    "dark-cyan"
    "grey"
    "dark-grey"
    "red"
    "green"
    "yellow"
    "blue"
    "magenta"
    "cyan"
    "white"
  ];
  colorOption =
    default: description:
    mkOption {
      type = types.enum colorNames;
      inherit default description;
    };

  consoleFont = pkgs.callPackage ../console-font/package.nix {
    inherit (cfg.font) family;
    fontPackages = config.fonts.packages;
  };
  consoleFontFile = "${consoleFont}/share/consolefonts/console.psf";

  # Characters the greeter can draw; "!" marks a lost connection to greetd.
  drawn = {
    inherit (cfg) dot placeholder;
    hint = cfg.wrongPasswordHint.text;
    fingerprint = cfg.fingerprint.text;
    error = "!";
  }
  // lib.optionalAttrs (cfg.cursor != null) { inherit (cfg) cursor; };
  glyphCheck =
    pkgs.runCommand "dot-greeter-glyph-check"
      {
        nativeBuildInputs = [ pkgs.python3 ];
      }
      ''
        python3 -I ${../console-font/check-glyphs.py} ${consoleFontFile} \
          ${lib.escapeShellArgs (lib.mapAttrsToList (name: text: "${name}=${text}") drawn)}
        touch $out
      '';

  pairs = flag: attrs: lib.concatLists (lib.mapAttrsToList (k: v: [ flag "${k}=${v}" ]) attrs);
  command = lib.escapeShellArgs (
    [
      (lib.getExe cfg.package)
      "--user"
      cfg.user
      "--placeholder"
      cfg.placeholder
      "--dot"
      cfg.dot
    ]
    ++ (if cfg.cursor == null then [ "--no-cursor" ] else [ "--cursor" cfg.cursor ])
    ++ [
      "--blink-ms"
      (toString cfg.blinkMs)
      "--hint"
      cfg.wrongPasswordHint.text
      "--hint-after"
      (toString cfg.wrongPasswordHint.attempts)
      "--fingerprint"
      cfg.fingerprint.text
    ]
    ++ pairs "--color" cfg.colors
    ++ pairs "--env" cfg.environment
    ++ [ "--" ]
    ++ cfg.command
  );
in
{
  options.services.dot-greeter = {
    enable = lib.mkEnableOption "the dot-greeter console login screen";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "dot-greeter package.";
    };

    user = mkOption {
      type = types.str;
      description = "The only user who logs in; the greeter never asks for a name.";
    };

    command = mkOption {
      type = types.listOf types.str;
      default = [ "${config.programs.hyprland.package}/bin/start-hyprland" ];
      defaultText = lib.literalExpression ''[ "''${config.programs.hyprland.package}/bin/start-hyprland" ]'';
      description = "Session started after login.";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = {
        XDG_SESSION_TYPE = "wayland";
        XDG_CURRENT_DESKTOP = "Hyprland";
        XDG_SESSION_DESKTOP = "Hyprland";
      };
      description = "Environment of the session.";
    };

    placeholder = mkOption {
      type = types.str;
      default = "password";
      description = "Dim text shown while nothing is typed.";
    };

    dot = mkOption {
      type = types.str;
      default = "•";
      description = "Character drawn for each typed letter. One character from the console font.";
    };

    cursor = mkOption {
      type = types.nullOr types.str;
      default = "│";
      description = "Blinking cursor, one character from the console font; null hides it.";
    };

    blinkMs = mkOption {
      type = types.ints.positive;
      default = 530;
      description = "How long the cursor stays on, and then off, in milliseconds.";
    };

    wrongPasswordHint = {
      attempts = mkOption {
        type = types.ints.unsigned;
        default = 3;
        description = "Wrong passwords in a row before the placeholder turns into the hint. 0 turns the hint off.";
      };
      text = mkOption {
        type = types.str;
        default = "check caps lock";
        description = "Text shown instead of the placeholder after that many wrong passwords.";
      };
    };

    fingerprint = {
      text = mkOption {
        type = types.str;
        default = "touch the sensor";
        description = "Text next to the pulsing dot while the fingerprint reader waits.";
      };
      timeout = mkOption {
        type = types.nullOr types.ints.positive;
        default = 10;
        description = ''
          Seconds pam_fprintd waits for a finger before PAM asks for the password (null keeps
          the fprintd default of 30). PAM cannot take a password during that wait; a password
          entered with Enter meanwhile is sent as soon as the wait ends. Applies to the "login"
          PAM service, which greetd uses as a substack (text console logins too).
        '';
      };
    };

    colors = {
      typed = colorOption "white" "Typed dots, and the light of the checking animation.";
      cursor = colorOption "grey" "Blinking cursor.";
      placeholder = colorOption "dark-grey" "Placeholder and questions from PAM.";
      wrong = colorOption "red" "Dots after a wrong password.";
      checking = colorOption "dark-grey" "Dots that are not lit during the checking animation.";
      hint = colorOption "dark-red" "Hint after several wrong passwords.";
      fingerprint = colorOption "white" "Brightest step of the pulsing fingerprint dot.";
    };

    quietBoot = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Hide boot text (systemd status lines and udev messages), so the screen stays black until
        the greeter. Failures still show, and everything stays in the journal.
      '';
    };

    font = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Use the font below on the whole Linux console (greeter and Ctrl+Alt+F2).";
      };
      family = mkOption {
        type = types.str;
        default = builtins.head config.fonts.fontconfig.defaultFonts.monospace;
        defaultText = lib.literalExpression "builtins.head config.fonts.fontconfig.defaultFonts.monospace";
        description = "Monospaced fontconfig family from fonts.packages, converted to a 16x32 console font.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings.default_session = {
        user = "greeter";
        inherit command;
      };
    };

    console = lib.mkIf cfg.font.enable {
      font = consoleFontFile;
      earlySetup = true;
    };

    # Builds the glyph check together with the system.
    system.extraDependencies = lib.optional cfg.font.enable glyphCheck;

    security.pam.services.login.rules.auth.fprintd.args =
      lib.mkIf (config.services.fprintd.enable && cfg.fingerprint.timeout != null)
        [ "timeout=${toString cfg.fingerprint.timeout}" ];

    # Keeps kernel warnings from printing over the greeter on tty1.
    boot.consoleLogLevel = lib.mkDefault 3;

    boot.kernelParams = lib.mkIf cfg.quietBoot [
      "quiet"
      "udev.log_level=3"
    ];
  };
}
