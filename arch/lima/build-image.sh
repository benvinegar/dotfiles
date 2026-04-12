#!/usr/bin/env bash
set -euo pipefail

ARCH_TARBALL_URL="${ARCH_TARBALL_URL:-http://de4.mirror.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz}"
WORKDIR="${WORKDIR:-$HOME/archlinux-arm-lima-build}"
IMG_BASENAME="${IMG_BASENAME:-archlinux-arm}"
IMG_SIZE="${IMG_SIZE:-12G}"
LIMA_USER_NAME="${LIMA_USER_NAME:-$(id -un)}"
LIMA_USER_UID="${LIMA_USER_UID:-$(id -u)}"
LIMA_USER_HOME="${LIMA_USER_HOME:-/home/${LIMA_USER_NAME}.guest}"
LIMA_USER_SHELL="${LIMA_USER_SHELL:-/bin/bash}"
LIMA_SSH_PUBKEY_FILE="${LIMA_SSH_PUBKEY_FILE:-}"
LIMA_SSH_PUBKEY="${LIMA_SSH_PUBKEY:-}"

if [ -z "$LIMA_SSH_PUBKEY" ] && [ -n "$LIMA_SSH_PUBKEY_FILE" ] && [ -f "$LIMA_SSH_PUBKEY_FILE" ]; then
  LIMA_SSH_PUBKEY="$(tr -d '\r' < "$LIMA_SSH_PUBKEY_FILE")"
fi

if [ -z "$LIMA_SSH_PUBKEY" ] && [ -f "$HOME/.lima/_config/user.pub" ]; then
  LIMA_SSH_PUBKEY="$(tr -d '\r' < "$HOME/.lima/_config/user.pub")"
fi

if [ -z "$LIMA_SSH_PUBKEY" ]; then
  echo "error: Lima SSH pubkey not found; set LIMA_SSH_PUBKEY or LIMA_SSH_PUBKEY_FILE" >&2
  exit 1
fi

RAW_IMG="$WORKDIR/$IMG_BASENAME.raw"
QCOW2_IMG="$WORKDIR/$IMG_BASENAME.qcow2"
TARBALL="$WORKDIR/$(basename "$ARCH_TARBALL_URL")"
ROOT="$WORKDIR/rootfs"
LOOPDEV=""

cleanup() {
  set +e

  sudo pkill -f "$ROOT/etc/pacman.d/gnupg" >/dev/null 2>&1 || true

  if mountpoint -q "$ROOT/dev"; then sudo umount -l "$ROOT/dev"; fi
  if mountpoint -q "$ROOT/proc"; then sudo umount -l "$ROOT/proc"; fi
  if mountpoint -q "$ROOT/sys"; then sudo umount -l "$ROOT/sys"; fi
  if mountpoint -q "$ROOT/run"; then sudo umount -l "$ROOT/run"; fi
  if mountpoint -q "$ROOT/boot"; then sudo umount -l "$ROOT/boot"; fi
  if mountpoint -q "$ROOT"; then sudo umount -l "$ROOT"; fi
  if [ -n "$LOOPDEV" ]; then sudo losetup -d "$LOOPDEV"; fi
}
trap cleanup EXIT

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }
}

for cmd in curl qemu-img parted losetup mkfs.vfat mkfs.ext4 blkid tar chroot systemctl; do
  require "$cmd"
done

mkdir -p "$WORKDIR"
rm -rf "$ROOT"
mkdir -p "$ROOT"

if [ ! -f "$TARBALL" ]; then
  echo "Downloading Arch Linux ARM rootfs..."
  curl -L "$ARCH_TARBALL_URL" -o "$TARBALL"
fi

rm -f "$RAW_IMG" "$QCOW2_IMG"
echo "Creating raw disk: $RAW_IMG ($IMG_SIZE)"
truncate -s "$IMG_SIZE" "$RAW_IMG"

sudo parted -s "$RAW_IMG" \
  mklabel gpt \
  mkpart ESP fat32 1MiB 513MiB \
  set 1 esp on \
  mkpart primary ext4 513MiB 100%

LOOPDEV="$(sudo losetup -Pf --show "$RAW_IMG")"
echo "Using loop device: $LOOPDEV"

sudo mkfs.vfat -F 32 -n AARCH64_EFI "${LOOPDEV}p1"
sudo mkfs.ext4 -F -L archlinux-root "${LOOPDEV}p2"

sudo mount "${LOOPDEV}p2" "$ROOT"
sudo mkdir -p "$ROOT/boot"
sudo mount "${LOOPDEV}p1" "$ROOT/boot"

echo "Extracting rootfs..."
sudo tar --numeric-owner -xpf "$TARBALL" -C "$ROOT"

BOOT_PARTUUID="$(sudo blkid -s PARTUUID -o value "${LOOPDEV}p1")"
ROOT_PARTUUID="$(sudo blkid -s PARTUUID -o value "${LOOPDEV}p2")"

sudo tee "$ROOT/etc/fstab" >/dev/null <<EOF
# Static information about the filesystems.
# See fstab(5) for details.

PARTUUID=${BOOT_PARTUUID}  /boot           vfat    rw,defaults  0 2
PARTUUID=${ROOT_PARTUUID}  /               ext4    rw,relatime  0 1
EOF

sudo mkdir -p "$ROOT/boot/EFI/systemd" "$ROOT/boot/EFI/BOOT" "$ROOT/boot/loader/entries"
sudo cp "$ROOT/usr/lib/systemd/boot/efi/systemd-bootaa64.efi" "$ROOT/boot/EFI/systemd/systemd-bootaa64.efi"
sudo cp "$ROOT/usr/lib/systemd/boot/efi/systemd-bootaa64.efi" "$ROOT/boot/EFI/BOOT/BOOTAA64.EFI"

sudo tee "$ROOT/boot/loader/loader.conf" >/dev/null <<EOF
default arch
timeout 0
editor no
console-mode max
auto-entries 0
auto-firmware 1
EOF

sudo tee "$ROOT/boot/loader/entries/arch.conf" >/dev/null <<EOF
title   Arch Linux ARM
linux   /Image
initrd  /initramfs-linux.img
options root=PARTUUID=${ROOT_PARTUUID} rw quiet
EOF

sudo tee "$ROOT/boot/loader/entries/arch-fallback.conf" >/dev/null <<EOF
title   Arch Linux ARM (fallback)
linux   /Image
initrd  /initramfs-linux-fallback.img
options root=PARTUUID=${ROOT_PARTUUID} rw
EOF

sudo rm -f "$ROOT/etc/resolv.conf"
sudo ln -s /run/systemd/resolve/stub-resolv.conf "$ROOT/etc/resolv.conf"
sudo mount --bind /dev "$ROOT/dev"
sudo mount --bind /proc "$ROOT/proc"
sudo mount --bind /sys "$ROOT/sys"
sudo mount --bind /run "$ROOT/run"

echo "Initializing pacman keyring and installing cloud guest packages..."
sudo chroot "$ROOT" /bin/bash -lc '
  set -euo pipefail
  systemd-sysusers
  pacman-key --init
  pacman-key --populate archlinuxarm
  pacman -Sy --noconfirm sudo openssh cloud-init cloud-guest-utils
  systemd-sysusers
'

sudo mkdir -p "$ROOT/etc/cloud/cloud.cfg.d"
sudo tee "$ROOT/etc/cloud/cloud.cfg.d/99_nocloud.cfg" >/dev/null <<'EOF'
datasource_list: [ NoCloud, None ]
datasource:
  NoCloud:
    fs_label: cidata
EOF

echo "Creating Lima user and SSH access..."
sudo chroot "$ROOT" /bin/bash -lc "
  set -euo pipefail
  if ! id -u '$LIMA_USER_NAME' >/dev/null 2>&1; then
    useradd -m -U -u '$LIMA_USER_UID' -d '$LIMA_USER_HOME' -s '$LIMA_USER_SHELL' -G wheel '$LIMA_USER_NAME'
  fi
  mkdir -p '$LIMA_USER_HOME/.ssh'
  chmod 700 '$LIMA_USER_HOME/.ssh'
  printf '%s\n' '$LIMA_SSH_PUBKEY' > '$LIMA_USER_HOME/.ssh/authorized_keys'
  chmod 600 '$LIMA_USER_HOME/.ssh/authorized_keys'
  chown -R '$LIMA_USER_NAME':'$LIMA_USER_NAME' '$LIMA_USER_HOME/.ssh'
  if [ ! -e '/home/$LIMA_USER_NAME.linux' ]; then
    ln -s '$(basename "$LIMA_USER_HOME")' '/home/$LIMA_USER_NAME.linux' || true
  fi
  mkdir -p /etc/sudoers.d
  echo '$LIMA_USER_NAME ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-lima-user
  chmod 440 /etc/sudoers.d/90-lima-user
"

sudo chroot "$ROOT" /usr/bin/systemd-tmpfiles --create >/dev/null || true
sudo systemctl --root="$ROOT" enable \
  sshd \
  systemd-networkd \
  systemd-resolved \
  systemd-timesyncd \
  cloud-init-local.service \
  cloud-init-network.service \
  cloud-init-main.service \
  cloud-config.service \
  cloud-final.service >/dev/null

cleanup
trap - EXIT

echo "Converting raw image to qcow2..."
qemu-img convert -f raw -O qcow2 -c "$RAW_IMG" "$QCOW2_IMG"
qemu-img info "$QCOW2_IMG"

echo
echo "Built image: $QCOW2_IMG"
