# bootc demos

A set of **standalone demos** for [bootc](https://github.com/containers/bootc) (bootable
containers). Each demo shows the **same OCI image consumed a different way** — one of bootc's
*consumption modes* — rather than one long pipeline.

Build a Linux OS as a container image, then run that *same image* as: a plain container, a
local VM, a cloud AMI on real EC2, and update/roll it back atomically.

## The two tracks

| Track | Runs on | Demos |
|-------|---------|-------|
| **Local / dev** | An existing **AWS Linux VM used as your dev machine** (native `podman` + `bcvk` + `bootc-image-builder`). The **Mac** is used only for the Podman Desktop GUI demo. | 01, 02, 03, 04 |
| **Cloud** | Build on the dev VM, deploy to a real **AWS EC2** instance. | 05, 06 |

> **Bare metal is out of scope** — these demos assume no physical hardware access.

## Demos

| # | Demo | Consumption mode | Where |
|---|------|------------------|-------|
| 01 | [Create a bootc container](./demos/01-create-bootc-container) | Build the OS as an OCI image (+ `bootc container lint`) | dev VM |
| 02 | [Run as a plain container](./demos/02-run-as-plain-container) | Standard container (podman/docker) — dev, CI, inspect | dev VM |
| 03 | [Run as a host OS in a local VM](./demos/03-run-as-host-os-local-vm) | Booted host OS via `bcvk` (systemd PID 1) | dev VM *(needs KVM)* |
| 04 | [Podman Desktop workflow](./demos/04-podman-desktop-workflow) | GUI build → disk export → boot VM | Mac |
| 05 | [Create an AMI, deploy to EC2](./demos/05-create-ami-deploy-ec2) | Cloud disk image on a real cloud host | dev VM → AWS |
| 06 | [Day-2 upgrade + rollback](./demos/06-day2-upgrade-rollback-ec2) | Atomic update & rollback of a running host | AWS EC2 |

Each demo folder has its own `README.md` and an idempotent `run.sh`.

## One-time setup

### On the AWS Linux dev VM (demos 01, 02, 03, 05, 06 build side)

```bash
# Fedora 42+ / CentOS Stream / RHEL with EPEL
sudo dnf install -y podman bootc-image-builder bcvk awscli qemu-kvm qemu-img virtiofsd libvirt openssh-clients
sudo systemctl enable --now libvirtd          # for `bcvk libvirt` (demo 03)
```

- **`bcvk`** is packaged in Fedora 42+ and EPEL 9/10. If unavailable, see
  [bcvk installation](https://github.com/bootc-dev/bcvk/blob/main/docs/src/installation.md).
- **Demo 03 needs KVM.** Check with `ls -l /dev/kvm`. On AWS this means a `*.metal` instance
  (or any nested-virt-capable type). No KVM → skip demo 03; demo 05 boots a real cloud host instead.

### On the Mac (demo 04 only)

Podman Desktop + the **bootc extension**. Install from
[podman-desktop.io/extensions/bootc](https://podman-desktop.io/docs/extensions/bootc-extension).

### Config

```bash
cp common/env.example common/env
$EDITOR common/env          # set REGISTRY, AWS_*, S3_BUCKET, INSTANCE_TYPE, arch, etc.
```

`common/env` is gitignored and holds no secrets. AWS credentials come from either an **EC2
instance role** (recommended when building on an EC2 host — nothing stored) or `~/.aws`; see
[demo 05](./demos/05-create-ami-deploy-ec2) for both.

## Base image

All demos build on **`quay.io/centos-bootc/centos-bootc:stream10`** — the smallest option, the
canonical base in upstream/Red Hat examples, RHEL-aligned, and it ships a default root
filesystem (so `bootc-image-builder` needs no `--rootfs`). To use Fedora instead, set
`BASE_IMAGE` in `common/env` (Fedora needs `--rootfs btrfs`/`ext4` — noted where relevant).

## Layout

```
common/                 shared helpers, env template, base Containerfile, bib config template
demos/0N-.../           one folder per demo: Containerfile (where relevant), run.sh, README.md
```

Every `run.sh` supports a `cleanup` subcommand to remove what it created.
