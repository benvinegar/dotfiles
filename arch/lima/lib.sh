#!/usr/bin/env bash

lima_load_defaults() {
  : "${INSTANCE_NAME:=archlinux-arm}"
  : "${BUILDER_INSTANCE:=ubuntu-builder}"
  : "${LIMA_USER_NAME:=$(id -un)}"
  : "${LIMA_USER_UID:=$(id -u)}"
  : "${LIMA_USER_HOME:=/home/${LIMA_USER_NAME}.guest}"
  : "${LIMA_USER_SHELL:=/usr/bin/zsh}"
  : "${LIMA_ARTIFACT_DIR:=${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/arch-lima}"
  : "${IMAGE_PATH:=$LIMA_ARTIFACT_DIR/${INSTANCE_NAME}.qcow2}"
  : "${TEMPLATE_PATH:=$LIMA_ARTIFACT_DIR/${INSTANCE_NAME}.yaml}"
  : "${LIMA_SSH_PUBKEY_PATH:=$HOME/.lima/_config/user.pub}"
  : "${INSTANCE_CONFIG:=${LIMA_HOME:-$HOME/.lima}/$INSTANCE_NAME/lima.yaml}"
  : "${REMOTE_DOTFILES_PATH:=$LIMA_USER_HOME/.dotfiles}"
}

lima_load_template_defaults() {
  lima_load_defaults
  : "${OUTPUT_PATH:=$TEMPLATE_PATH}"
}
