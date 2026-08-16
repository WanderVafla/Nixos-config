{ pkgs, inputs, ... }:

{
  home.username = "vladyslav";
  home.homeDirectory = "/home/vladyslav";

  home.stateVersion = "26.05";

  nixpkgs.config.allowUnfree = true;

  programs.git = {
    enable = true;
    userName = "WanderVafla";
    userEmail = "procenkovladik1@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
    };
  };

  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    matchBlocks = {
      "github.com" = {
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };

  services.ssh-agent.enable = true;

  home.packages = with pkgs; [
      inputs.zen-browser.packages.${pkgs.system}.default
      spotify
      
      chromium
      # ashell
      kdePackages.dolphin
      kdePackages.ark
      p7zip
      # vicinae
      # kitty
      zed-editor
      nixd
      nil
      
      direnv
      nix-direnv
      git
      micro
      obsidian
      opencode
      # Launguages
      php85
      rustc
      # Packages
      pnpm
      cargo

      phpPackages.composer
      nodejs_26

      sqlitebrowser
      # hyprcursor  
    ];

  imports = [
    ./modules
  ];
}
