# Official Claude Desktop (Electron), repackaged from Anthropic's .deb.
# To update: take Version and SHA256 from
# https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages
# and convert the hash with `nix hash convert --hash-algo sha256 --to sri <hex>`.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libsecret,
  libuuid,
  libxkbcommon,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  xorg,
  libayatana-appindicator,
  libseccomp,
  libcap_ng,
  xdg-utils,
  bubblewrap,
  socat,
  openssh,
}:

stdenv.mkDerivation rec {
  pname = "claude-desktop";
  version = "2.42304.2";

  src = fetchurl {
    url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${version}_amd64.deb";
    hash = "sha256-OKfVi1ipdsiMplLqovesAsh8SjiK4w9GjXK3kOa1f5A=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libnotify
    libpulseaudio
    libsecret
    libuuid
    libxkbcommon
    nspr
    nss
    pango
    pipewire
    systemd
    xorg.libX11
    xorg.libxcb
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxshmfence
    xorg.libXtst
    # Bundled virtiofsd, used by the Cowork VM.
    libseccomp
    libcap_ng
  ];

  # Electron loads these with dlopen, so they never show up as NEEDED entries.
  runtimeDependencies = [
    libGL
    libnotify
    libpulseaudio
    libsecret
    pipewire
    (lib.getLib systemd)
    libayatana-appindicator
  ];

  # Large prebuilt Electron binaries; stripping gains nothing and risks breaking them.
  dontStrip = true;

  # GSettings schemas for GTK dialogs; passed to the single wrapper made in postFixup.
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    # chrome-sandbox is SUID in the .deb, which the Nix sandbox cannot set. It is
    # not needed on NixOS: Chromium uses unprivileged user namespaces instead.
    dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner
    rm usr/lib/claude-desktop/chrome-sandbox
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/bin
    cp -r usr/lib/claude-desktop $out/lib/
    cp -r usr/share $out/
    # The Debian postinst copies the MIME types into place; do it at build time.
    install -Dm644 $out/lib/claude-desktop/resources/linux-mime/com.anthropic.Claude.xml \
      $out/share/mime/packages/com.anthropic.Claude.xml

    runHook postInstall
  '';

  # gappsWrapperArgs is only filled in during the fixup phase.
  postFixup = ''
    makeWrapper $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${
        lib.makeBinPath [
          xdg-utils
          bubblewrap
          socat
          openssh
        ]
      } \
      --add-flags "--ozone-platform-hint=auto --enable-wayland-ime=true"
  '';
}
