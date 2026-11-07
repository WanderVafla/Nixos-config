{ pkgs, ... }:

{
  home.packages = with pkgs; [
    eza
    bat
    ripgrep
    fd
  ];

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
  
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh.shellAliases = {
    ls = "eza --icons";
    ll = "eza -lah --icons --git";
    less = "bat";
    cl = "clear";
    home-update = "home-manager switch --flake ~/.config/nixos";
    nix-rebuild = "sudo nixos-rebuild switch --flake ~/.config/nixos";
  };

  home.sessionVariables = {
    EDITOR = "micro";
    PAGER = "bat";
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh.plugins = [
    {
      name = "fzf-tab";
      src = pkgs.zsh-fzf-tab;
      file = "share/fzf-tab/fzf-tab.plugin.zsh";
    }
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion = {
      enable = true;
    };
    syntaxHighlighting = {
      enable = true;
    };
    history = {
      size = 50000;
      ignoreAllDups = true;
      share = true;
    };
    initContent = ''
      autoload -Uz vcs_info add-zsh-hook
      add-zsh-hook precmd vcs_info
      setopt PROMPT_SUBST
      zstyle ':vcs_info:*' enable git
      zstyle ':vcs_info:git:*' formats ' (%b)'

      PROMPT='%F{240}%*%f%F{blue} %~%f%F{yellow}''${vcs_info_msg_0_}%f > '
    '';
  };
}
