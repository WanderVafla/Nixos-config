# Chat with the Hermes agent on the homelab server from a Noctalia panel.
# The plugin runs `hermes-chat-remote`, which forwards to `hermes-chat` on the server over SSH:
# the SSH login is the authorization, and no API key is stored on this machine.
{ config, lib, pkgs, ... }:

let
  cfg = config.hermesChat;

  # Usage is the same as hermes-chat on the server: new | send <id> | messages <id> | approve <run> <choice>.
  hermesChatRemote = pkgs.writeShellApplication {
    name = "hermes-chat-remote";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      # BatchMode fails fast instead of prompting: the panel has no terminal for a passphrase.
      # The shared connection makes every message after the first one skip the SSH handshake.
      exec ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=10 \
        -o ServerAliveInterval=15 \
        -o ControlMaster=auto \
        -o "ControlPath=''${XDG_RUNTIME_DIR:-/tmp}/hermes-chat-ssh-%C" \
        -o ControlPersist=10m \
        ${lib.escapeShellArg cfg.sshHost} hermes-chat "$@"
    '';
  };
in
{
  options.hermesChat.sshHost = lib.mkOption {
    type = lib.types.str;
    default = "homelab";
    description = "SSH host (an alias from ~/.ssh/config works) that has the hermes-chat command.";
  };

  config.home.packages = [ hermesChatRemote ];
}
