# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.noctalia-greeter.nixosModules.default
    ./system/greeter.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # nix.settings.auto-optimise-store = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;
  boot.initrd.services.lvm.enable = false;
  boot.initrd.systemd.tpm2.enable = false;
  # Keeps the initrd as small as xz does, but without xz's ~1.2 s slower unpacking at boot.
  boot.initrd.compressor = "zstd";
  boot.initrd.compressorArgs = [ "-19" "-T0" ];
  # Mount /boot on first access (nixos-rebuild) instead of at boot: mounting it took ~1.7 s and
  # held up local-fs.target, and with it everything up to the login screen.
  # nofail keeps /boot out of local-fs.target's requirements: on a live switch /boot is already
  # mounted, boot.automount refuses to start, and without nofail that failure sends the whole
  # system into emergency mode.
  fileSystems."/boot".options = [
    "noauto"
    "nofail"
    "x-systemd.automount"
  ];
  # /boot is only 196 MB and every generation keeps its own kernel and initrd there.
  boot.loader.systemd-boot.configurationLimit = 3;
  systemd.services.NetworkManager-wait-online.enable = false;

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
  virtualisation.docker.enableOnBoot = false;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "JT-24-11-07-vladyslav"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager = {
    enable = true;
  };
  # Cours d'APL. Installed but not started at boot: stopping it cost 1-2 s of every shutdown.
  # Start it for class with `sudo systemctl start netbird`.
  services.netbird.enable = true;
  systemd.services.netbird.wantedBy = lib.mkForce [ ];

  virtualisation.libvirtd = {
    onBoot = false;
    # Shut running VMs down at power-off instead of saving their memory to disk (the default
    # "suspend" wrote the alpine VM out and added ~1 s to shutdown).
    onShutdown = "shutdown";
    # enable = true;
    qemu.swtpm.enable = true;
  };

  virtualisation.spiceUSBRedirection.enable = true;
  virtualisation.docker.enable = true;
  programs.virt-manager.enable = true;

  services.journald.settings.Journal.SystemMaxUse = "300M";
  services.fwupd.enable = true;

  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = true;
  # security.pam.services.greeter.fprintAuth = true;
  security.pam.services.sudo.fprintAuth = true;

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      cups-filters
      foomatic-db
      foomatic-db-ppds
      foomatic-db-engine
    ];
  };

  hardware.printers = {
    ensurePrinters = [
      {
        name = "Sharp-MX2651";
        location = "portable";
        deviceUri = "socket://printer.localdomain:9100";
        model = "foomatic-db-ppds/Generic-PCL_6_PCL_XL_Printer-pxlcolor.ppd.gz";
        ppdOptions = {
          PageSize = "A4";
        };
      }
    ];
    ensureDefaultPrinter = "Sharp-MX2651";
  };

  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Set your time zone.
  time.timeZone = "Europe/Zurich";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."vladyslav" = {
    isNormalUser = true;
    description = "Vladyslav Chuhunov";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "video"
      "libvirtd"
    ];
    shell = pkgs.zsh;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.dbus.enable = true;

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      zlib
      openssl
      stdenv.cc.cc.lib
      libpulseaudio
    ];
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    tmux
    btop
    home-manager
    fastfetch
    playerctl
    (callPackage ./packages/claude-desktop.nix { })
  ];

  # Secret Service for apps that store logins and tokens (Claude Desktop, Chromium),
  # unlocked with the login password at the greetd prompt.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ 8000 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  hardware.enableAllFirmware = true;

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.gvfs.enable = true;
  security.polkit.enable = true;
  services.tailscale = {
    enable = true;
    extraUpFlags = [
      "--operator=vladyslav"
    ];
  };

  programs.hyprland = {
    enable = true;
  };

  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
    };
    gamemode.enable = true;
  };

  programs.zsh = {
    enable = true;
  };

  programs.nh = {
    enable = true;
    flake = "/home/vladyslav/.config/nixos";
    clean = {
      enable = true;
      extraArgs = "--keep-since 14d --keep 5";
    };
  };

  services.displayManager.noctalia-greeter = {
    enable = true;

    settings = {
      # Настройки курсора (согласно документации: [cursor])
      cursor = {
        path = pkgs.bibata-cursors;
        size = 46;
        theme = "Bibata-Modern-Ice";
      };

      # Настройки клавиатуры (согласно документации: [keyboard])
      keyboard = {
        layout = "us";
      };

      # Настройки оформления и обоев (согласно документации: [appearance.wallpaper])
      appearance = {
        wallpaper = {
          path = "${./home/Wallpapers/14.png}"; # Автоматически помещает файл в /nix/store
          fill_mode = "crop"; # Варианты: "crop", "fit", "stretch", "center", "repeat", "span"
          fill_color = "#000000"; # Цвет фона при режимах fit/center
        };
      };
    };
  };

  # User fonts live in home/modules/fonts. The default set (DejaVu, Liberation, Noto emoji)
  # stays system-wide so the greeter and other system services still have text fonts.
  fonts.enableDefaultPackages = true;

  services.displayManager = {
    sddm = {
      enable = false;
      theme = "chili";
      wayland.enable = true;
    };
    defaultSession = "hyprland";
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-termfilechooser
    ];
    config = {
      common = {
        default = [ "gtk" ];
      };
      hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Screencast" = [ "hyprland" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
      };
    };
  };

  # Make GTK apps open files through the portal (yazi) instead of their own dialog
  environment.sessionVariables.GTK_USE_PORTAL = "1";
}
