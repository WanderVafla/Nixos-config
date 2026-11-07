{ inputs, lib, ... }:

let
  # Installed automatically, configurable/disableable from the GUI
  extension = slug: {
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
    installation_mode = "normal_installed";
  };

  # Default value only: changes made in the GUI are kept in prefs.js
  pref = value: {
    Value = value;
    Status = "default";
  };
in
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  programs.zen-browser = {
    enable = true;

    policies = {
      DisableAppUpdate = false;
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      OfferToSaveLogins = true;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };

      ExtensionSettings = {
        "uBlock0@raymondhill.net" = extension "ublock-origin";
        "addon@darkreader.org" = extension "darkreader";
        "firefox-extension@deepl.com" = extension "deepl-translate";
        "{710ec9db-6f38-4798-90b9-7486b2285bfb}" = extension "pomodoro-clock";
        "arc-dark-theme@afnankhan" = extension "arc-dark-theme-we";
        "fr-dicollecte@dictionaries.addons.mozilla.org" = extension "dictionnaire-fran%C3%A7ais1";
      };

      Preferences = lib.mapAttrs (_: pref) {
        # Zen
        "zen.welcome-screen.seen" = true;
        "zen.urlbar.behavior" = "float";
        "zen.view.use-single-toolbar" = false;
        "zen.view.compact.enable-at-startup" = false;
        "zen.view.compact.toolbar-flash-popup" = true;
        "zen.view.window.scheme" = 0;
        "zen.workspaces.show-workspace-indicator" = true;
        "zen.workspaces.indicator-name-center" = false;

        # UI
        "browser.uidensity" = 2;
        "browser.tabs.inTitlebar" = 1;
        "sidebar.visibility" = "hide-on-close";
        "findbar.highlightAll" = true;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "devtools.chrome.enabled" = true;

        # Search & network
        "browser.urlbar.suggest.searches" = false;
        "network.dns.disablePrefetch" = true;
        "network.prefetch-next" = false;
        "network.http.speculative-parallel-limit" = 0;

        # Locale & privacy
        "intl.accept_languages" = "en,en-us";
        "privacy.clearOnShutdown_v2.formdata" = true;
      };
    };
  };
}
