{ pkgs, inputs, ... }:

{

  imports = [
    ./modules
  ];

  home.username = "vladyslav";
  home.homeDirectory = "/home/vladyslav";

  home.stateVersion = "26.05";

  nixpkgs.config.allowUnfree = true;

  programs.git = {
    enable = true;
    settings = {
      user.name = "WanderVafla";
      user.email = "procenkovladik1@gmail.com";
      init.defaultBranch = "main";
    };
  };

  programs.ssh = {
    enable = true;
    # addKeysToAgent = "yes";
    matchBlocks = {
      "github.com" = {
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };

  services.ssh-agent.enable = true;

  home.packages = with pkgs; [
    hurl
    gh

    inputs.spotifast.packages.${pkgs.stdenv.hostPlatform.system}.default

    noctalia
    spotify
    brightnessctl

    kdePackages.dolphin
    kdePackages.ark
    p7zip
    zed-editor
    nixd
    nil


    nwg-displays
    # direnv
    # nix-direnv
    git
    micro
    obsidian
    # Agents
    claude-code
    opencode
    # Launguages
    php85
    rustc
    # Packages
    pnpm
    cargo

    phpPackages.composer
    # nodejs_26

    sqlitebrowser

    # noctalia
    networkmanagerapplet
    grim
    slurp

    python312
    uv

    pandoc # convert files also need to obsidian plugins
    typst

    bun
    tree
    nodejs_latest
    dive
    llama-cpp-vulkan

    ganttproject-bin
    postman
  ];

  # Open HTTP and HTTPS ports
  # networking.firewall.allowedTCPPorts = [ 80 443 ];
}
