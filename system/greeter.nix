# Login screen: dot-greeter on the console instead of noctalia-greeter.
# All options with their defaults: packages/dot-greeter/module.nix.
# Rollback: remove this file from `imports` in configuration.nix.
{ lib, ... }:

{
  imports = [ ../packages/dot-greeter/module.nix ];

  services.displayManager.noctalia-greeter.enable = lib.mkForce false;

  services.dot-greeter = {
    enable = true;
    user = "vladyslav";

    font.enable = false;
    cursor = null;

    placeholder = "password";
    wrongPasswordHint = {
      # Wrong passwords in a row before the hint replaces the placeholder; 0 turns it off.
      attempts = 3;
      text = "check caps lock";
    };

    fingerprint = {
      text = "touch the sensor";
      # Seconds to wait for a finger before the password is accepted (fprintd default: 30).
      timeout = 10;
    };

    # dot = "•";
    # cursor = "│";   # null hides the cursor
    # blinkMs = 530;
    # colors = { typed = "white"; cursor = "grey"; placeholder = "dark-grey"; wrong = "red"; hint = "dark-red"; fingerprint = "white"; };
    # The console font follows fonts.fontconfig.defaultFonts.monospace unless set here:
    # font.family = "DejaVu Sans Mono";
  };
}
