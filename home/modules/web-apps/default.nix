# Websites launched as standalone Chromium app windows, without browser UI.
# All of them share the default Chromium profile, so one browser instance (and
# its GPU and network processes) serves every app; each window adds only a renderer.
{ ... }:

let
  webApp =
    {
      name,
      url,
      icon,
      categories,
    }:
    {
      inherit name categories;
      icon = "${icon}";
      exec = "chromium --app=${url}";
      terminal = false;
    };
in
{
  xdg.desktopEntries = {
    discord-web = webApp {
      name = "Discord";
      url = "https://discord.com/channels/@me";
      icon = ./icons/discord.png;
      categories = [
        "Network"
        "InstantMessaging"
      ];
    };
  };
}
