# Single Node NixOS ISO Builder

This project builds burnable NixOS live ISOs for a single-node k3s machine.

The live system:

- includes k3s configured as a single server node, but does not start it automatically
- creates `/persistent` and stores k3s data under `/persistent/k3s`
- creates `/versions` and writes build metadata to `/versions/current-system`
- saves the current architecture's `auto-updater` binary to `/versions/auto-updater`
- saves the binary checksum to `/versions/auto-updater.sha256`
- runs `auto-updater` on the primary terminal, `tty1`, at startup
- enables SSH and NetworkManager

The default login is:

- username: `nixos`
- password: `nixos`

Start k3s manually with:

```sh
sudo systemctl start k3s
```

## Build Locally

Build the amd64 ISO:

```sh
nix build .#packages.x86_64-linux.iso
```

Build the aarch64 ISO:

```sh
nix build .#packages.aarch64-linux.iso
```

The built ISO is available under:

```sh
result/iso/
```

The `auto-updater` binary is pulled from the latest release of `daniel-brenot/auto-updater`. In GitHub Actions, the flake inputs are refreshed before each release build so the ISO uses the latest `auto-updater-linux-amd64` or `auto-updater-linux-aarch64` asset.

To refresh the binary before a local build, run:

```sh
nix flake lock --update-input auto-updater-amd64 --update-input auto-updater-aarch64
```

## Burn To USB

On Linux, replace `/dev/sdX` with the USB device, not a partition:

```sh
sudo dd if=result/iso/single-node-k3s-x86_64-linux.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

For aarch64, use `single-node-k3s-aarch64-linux.iso`.

The ISO is configured with `makeUsbBootable`, so the same image can be written directly to a USB drive.

## Bundled Auto Updater

At boot, the ISO copies the bundled binary to:

```sh
/versions/auto-updater
```

and writes its SHA-256 hash to:

```sh
/versions/auto-updater.sha256
```

The binary is also installed on `PATH` as `auto-updater`.

## Persistence

The live system always creates `/persistent` and `/versions` at boot. The ISO itself is read-only, so data under those paths only survives reboot if you mount writable storage there after boot or customize this configuration to mount a persistent partition at `/persistent`.

## GitHub Releases

The workflow in `.github/workflows/release.yml` builds both architectures and publishes:

- `single-node-k3s-amd64.iso`
- `single-node-k3s-amd64.iso.sha256`
- `single-node-k3s-aarch64.iso`
- `single-node-k3s-aarch64.iso.sha256`

It runs when you push a tag matching `v*`:

```sh
git tag v0.1.0
git push origin v0.1.0
```

You can also run it manually from GitHub Actions and provide the release tag.
