# Chromium, used mainly to run websites as standalone app windows (see web-apps.nix).
{ ... }:

{
  programs.chromium = {
    enable = true;

    commandLineArgs = [
      # Native Wayland: no XWayland layer, and Hyprland draws no title bar on app windows.
      "--ozone-platform=wayland"
      # Move rasterization and video decoding from the CPU to the GPU.
      "--enable-gpu-rasterization"
      "--enable-zero-copy"
      "--enable-features=AcceleratedVideoDecodeLinuxGL"
    ];

    extensions = [
      # uBlock Origin Lite: fewer ad and tracker scripts for web apps to run.
      { id = "ddkjiahejlhfcafbddmgiahcphecmpfh"; }
    ];
  };
}
