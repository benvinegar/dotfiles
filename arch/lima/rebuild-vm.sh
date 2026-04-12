#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_IMAGE_SCRIPT="$SCRIPT_DIR/build-image.sh"
WRITE_TEMPLATE_SCRIPT="$SCRIPT_DIR/write-template.sh"

INSTANCE_NAME="${INSTANCE_NAME:-archlinux-arm}"
BUILDER_INSTANCE="${BUILDER_INSTANCE:-ubuntu-builder}"
LIMA_USER_NAME="${LIMA_USER_NAME:-$(id -un)}"
LIMA_USER_UID="${LIMA_USER_UID:-$(id -u)}"
LIMA_USER_HOME="${LIMA_USER_HOME:-/home/${LIMA_USER_NAME}.guest}"
LIMA_USER_SHELL="${LIMA_USER_SHELL:-/bin/bash}"
ARTIFACT_DIR="${LIMA_ARTIFACT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/arch-lima}"
IMAGE_PATH="$ARTIFACT_DIR/${INSTANCE_NAME}.qcow2"
TEMPLATE_PATH="$ARTIFACT_DIR/${INSTANCE_NAME}.yaml"
SSH_PUBKEY_PATH="${LIMA_SSH_PUBKEY_PATH:-$HOME/.lima/_config/user.pub}"
BUILDER_DEPS="${BUILDER_DEPS:-qemu-utils parted dosfstools e2fsprogs util-linux systemd-container curl rsync}"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }
}

builder_exists() {
  limactl list | awk 'NR>1 {print $1}' | grep -qx "$BUILDER_INSTANCE"
}

ensure_builder() {
  if limactl shell "$BUILDER_INSTANCE" -- true >/dev/null 2>&1; then
    return 0
  fi

  if builder_exists; then
    echo "Starting existing builder VM: $BUILDER_INSTANCE"
    limactl start --yes "$BUILDER_INSTANCE"
    return 0
  fi

  echo "Creating builder VM: $BUILDER_INSTANCE"
  limactl start --name="$BUILDER_INSTANCE" --yes template://ubuntu
}

main() {
  require limactl

  if [ ! -f "$SSH_PUBKEY_PATH" ]; then
    echo "error: Lima SSH pubkey not found at $SSH_PUBKEY_PATH" >&2
    exit 1
  fi

  ensure_builder

  echo "Installing builder dependencies in $BUILDER_INSTANCE"
  limactl shell "$BUILDER_INSTANCE" -- bash -lc "sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $BUILDER_DEPS"

  local builder_home builder_workdir remote_build_script remote_pubkey remote_image build_cmd
  builder_home="$(limactl shell "$BUILDER_INSTANCE" -- bash -lc 'printf %s "$HOME"')"
  builder_workdir="${BUILDER_WORKDIR:-$builder_home/dotfiles-lima-build/$INSTANCE_NAME}"
  remote_build_script="$builder_workdir/build-image.sh"
  remote_pubkey="$builder_workdir/lima-user.pub"
  remote_image="$builder_workdir/${INSTANCE_NAME}.qcow2"

  limactl shell "$BUILDER_INSTANCE" -- bash -lc "mkdir -p $(printf %q "$builder_workdir")"
  limactl copy --backend=scp "$BUILD_IMAGE_SCRIPT" "$BUILDER_INSTANCE:$remote_build_script"
  limactl copy --backend=scp "$SSH_PUBKEY_PATH" "$BUILDER_INSTANCE:$remote_pubkey"

  printf -v build_cmd '%q ' \
    env \
    "WORKDIR=$builder_workdir" \
    "IMG_BASENAME=$INSTANCE_NAME" \
    "LIMA_USER_NAME=$LIMA_USER_NAME" \
    "LIMA_USER_UID=$LIMA_USER_UID" \
    "LIMA_USER_HOME=$LIMA_USER_HOME" \
    "LIMA_USER_SHELL=$LIMA_USER_SHELL" \
    "LIMA_SSH_PUBKEY_FILE=$remote_pubkey" \
    "$remote_build_script"

  echo "Building Arch Linux ARM image in $BUILDER_INSTANCE"
  limactl shell "$BUILDER_INSTANCE" -- bash -lc "chmod +x $(printf %q "$remote_build_script") && $build_cmd"

  mkdir -p "$ARTIFACT_DIR"
  echo "Copying image to host: $IMAGE_PATH"
  limactl copy --backend=scp "$BUILDER_INSTANCE:$remote_image" "$IMAGE_PATH"

  echo "Writing Lima template: $TEMPLATE_PATH"
  OUTPUT_PATH="$TEMPLATE_PATH" \
  IMAGE_PATH="$IMAGE_PATH" \
  INSTANCE_NAME="$INSTANCE_NAME" \
  LIMA_USER_NAME="$LIMA_USER_NAME" \
  LIMA_USER_UID="$LIMA_USER_UID" \
  LIMA_USER_HOME="$LIMA_USER_HOME" \
  LIMA_USER_SHELL="$LIMA_USER_SHELL" \
  "$WRITE_TEMPLATE_SCRIPT" >/dev/null

  echo "Recreating Lima instance: $INSTANCE_NAME"
  limactl delete -f "$INSTANCE_NAME" >/dev/null 2>&1 || true
  limactl start --name="$INSTANCE_NAME" --yes "$TEMPLATE_PATH"

  cat <<EOF

Next step:
  $SCRIPT_DIR/bootstrap-dotfiles.sh

Artifacts:
  image:    $IMAGE_PATH
  template: $TEMPLATE_PATH
EOF
}

main "$@"
