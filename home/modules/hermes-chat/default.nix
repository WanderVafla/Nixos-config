# Chat with the Hermes agent and watch homelab deploys from a Noctalia panel.
# The plugin runs the wrappers below, which forward to commands on the server over SSH:
# the SSH login is the authorization, and no API key is stored on this machine.
{ config, lib, pkgs, ... }:

let
  cfg = config.hermesChat;

  # BatchMode fails fast instead of prompting: the panel has no terminal for a passphrase.
  # The shared connection lets every call after the first one skip the SSH handshake.
  sshOptions = ''
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o ServerAliveInterval=15 \
    -o ControlMaster=auto \
    -o "ControlPath=''${XDG_RUNTIME_DIR:-/tmp}/hermes-chat-ssh-%C" \
    -o ControlPersist=10m \
  '';
  host = lib.escapeShellArg cfg.sshHost;

  # Same usage as hermes-chat on the server: new | sessions | send <id> | messages <id> | approve <run> <choice>.
  hermesChatRemote = pkgs.writeShellApplication {
    name = "hermes-chat-remote";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      exec ssh ${sshOptions} ${host} hermes-chat "$@"
    '';
  };

  # Read-only deploy status as JSON (homelab-deploy-status on the server).
  homelabDeployStatus = pkgs.writeShellApplication {
    name = "homelab-deploy-status-remote";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      exec ssh ${sshOptions} ${host} homelab-deploy-status
    '';
  };

  # Interactive on purpose: approving needs the sudo password and a y/N answer on the server.
  # The panel opens it in a terminal; it waits for Enter so the result stays readable.
  homelabDeployApprove = pkgs.writeShellApplication {
    name = "homelab-deploy-approve";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      status=0
      ssh -t ${host} sudo homelab-deploy approve || status=$?
      echo
      read -r -p "Done (exit code $status). Press Enter to close." _
      exit "$status"
    '';
  };
in
{
  options.hermesChat.sshHost = lib.mkOption {
    type = lib.types.str;
    default = "homelab";
    description = "SSH host (an alias from ~/.ssh/config works) that has hermes-chat and homelab-deploy.";
  };

  config.home.packages = [ hermesChatRemote homelabDeployStatus homelabDeployApprove ];
}
