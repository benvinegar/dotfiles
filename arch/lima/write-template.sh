#!/usr/bin/env bash
set -euo pipefail

INSTANCE_NAME="${INSTANCE_NAME:-archlinux-arm}"
LIMA_USER_NAME="${LIMA_USER_NAME:-$(id -un)}"
LIMA_USER_UID="${LIMA_USER_UID:-$(id -u)}"
LIMA_USER_HOME="${LIMA_USER_HOME:-/home/${LIMA_USER_NAME}.guest}"
LIMA_USER_SHELL="${LIMA_USER_SHELL:-/usr/bin/zsh}"
ARTIFACT_DIR="${LIMA_ARTIFACT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/arch-lima}"
IMAGE_PATH="${IMAGE_PATH:-$ARTIFACT_DIR/${INSTANCE_NAME}.qcow2}"
OUTPUT_PATH="${OUTPUT_PATH:-$ARTIFACT_DIR/${INSTANCE_NAME}.yaml}"

mkdir -p "$(dirname "$OUTPUT_PATH")"

cat > "$OUTPUT_PATH" << EOF
minimumLimaVersion: 2.0.0

vmType: vz
arch: aarch64

images:
  - location: file://${IMAGE_PATH}

mounts: []

ssh:
  loadDotSSHPubKeys: false

containerd:
  system: false
  user: false

user:
  name: ${LIMA_USER_NAME}
  uid: ${LIMA_USER_UID}
  home: ${LIMA_USER_HOME}
  shell: ${LIMA_USER_SHELL}
EOF

echo "$OUTPUT_PATH"
