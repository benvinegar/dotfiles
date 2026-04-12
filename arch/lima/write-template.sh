#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
lima_load_template_defaults

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
