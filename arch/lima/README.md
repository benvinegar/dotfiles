# Native Arch Linux ARM on Lima

This directory codifies the workflow for rebuilding a **native `aarch64` Arch Linux ARM** Lima VM on **macOS Apple Silicon** with:

- `vmType: vz`
- isolated guest filesystem (`mounts: []`)
- Lima guest agent + readiness working
- dotfiles bootstrap from this repo
- `zsh` as the Lima shell after bootstrap

## Files

- `build-image.sh` — build a Lima-ready Arch Linux ARM qcow2 image inside a Linux builder VM
- `write-template.sh` — render a local Lima template YAML for the built image
- `rebuild-vm.sh` — host orchestration script to build, copy, template, and recreate the VM
- `bootstrap-dotfiles.sh` — copy this repo into the guest and run `./arch/setup.sh` + `./install.sh`

## One-command rebuild on the host

```bash
~/.dotfiles/arch/lima/rebuild-vm.sh
```

By default this script:

1. ensures a builder VM named `ubuntu-builder` exists and is running
2. installs builder dependencies in that VM
3. copies `build-image.sh` and the Lima public key into the builder
4. builds the Arch Linux ARM qcow2 image in the builder
5. copies the image back to the host
6. writes a Lima template YAML next to the image
7. recreates the `archlinux-arm` VM from that template

## Bootstrap dotfiles into the guest

```bash
~/.dotfiles/arch/lima/bootstrap-dotfiles.sh
```

This copies the repo into the guest as `~/.dotfiles` and runs:

```bash
./arch/setup.sh --noconfirm
./install.sh
```

It also updates the instance config and restarts the VM if needed so `limactl shell <instance>` opens `zsh` instead of `bash`.

## Default local artifact locations

These scripts intentionally write large machine-local artifacts **outside the git repo**.

By default they use:

- image dir: `${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/arch-lima`
- image path: `${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/arch-lima/archlinux-arm.qcow2`
- template path: `${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/arch-lima/archlinux-arm.yaml`

Override with environment variables if desired.

## Useful environment overrides

- `INSTANCE_NAME` — target Lima instance name (default `archlinux-arm`)
- `BUILDER_INSTANCE` — builder VM name (default `ubuntu-builder`)
- `LIMA_ARTIFACT_DIR` — where to store the rebuilt qcow2 + rendered template on the host
- `LIMA_USER_NAME` — guest username (default current host username)
- `LIMA_USER_UID` — guest UID (default current host UID)
- `LIMA_USER_HOME` — guest home (default `/home/<user>.guest`)
- `LIMA_USER_SHELL` — guest shell (default `/usr/bin/zsh`)
- `LIMA_SSH_PUBKEY_PATH` — Lima user public key file (default `~/.lima/_config/user.pub`)
- `BUILDER_WORKDIR` — build workspace inside the builder VM

Example:

```bash
LIMA_ARTIFACT_DIR="$HOME/Projects/lima-images" \
INSTANCE_NAME=archlinux-arm \
~/.dotfiles/arch/lima/rebuild-vm.sh
```

## Notes

- The VM is Lima-ready because the baked image includes `cloud-init` + `cloud-guest-utils` and is configured for the `NoCloud` datasource with fs label `cidata`.
- The baked image also includes `zsh`, and the rendered template defaults the Lima user shell to `/usr/bin/zsh`.
- The rendered template disables Lima-managed containerd for now because rootless containerd setup was a source of noisy startup failures during debugging.
- `cloud-init status --long` may still report `degraded done` because Lima's generated cloud-config currently uses deprecated fields, but the VM is functionally ready when Lima reports `READY` and the guest agent is active.
