# Demo 01 — Create a bootc container

**Consumption mode:** define a whole Linux OS as a standard OCI image.
**Runs on:** the AWS Linux dev VM (or any Linux with `podman`).

## What this proves

The operating system is *built like any container* — a `Containerfile`, `podman build`, a
normal OCI image in your registry. No ISO, no Kickstart, no separate OS toolchain. The image
this demo builds is the **single artifact** reused by demos 02, 03, 05, and 06.

It also applies the brief's **Core Best Practices**:

- **`/usr` vs `/var`:** image-bound web content is moved from `/var/www` (mutable state) into
  `/usr/share/www` (immutable at boot) and symlinked back — so content ships and updates *with
  the image*.
- **Offline configuration:** files are written directly during build (no live `systemd`/`dbus`).
- **Filesystem hygiene:** `/var` and `/run` hold machine-local state that is reset/regenerated
  at boot, so build-time leftovers there (dnf cache + history, logs, subscription-manager
  artifacts) don't belong in the image. A cleanup step clears them right before the lint.
- **`bootc container lint`** is the final build step — it validates a single kernel, kernel
  args, and filesystem hygiene.

The image definition is [`common/Containerfile.base`](../../common/Containerfile.base) (shared so
every demo builds the exact same OS).

## Prerequisites

- `podman` (rootful or rootless both fine for building)
- Network access to pull the base image (~800 MB first time)

## Run

```bash
./run.sh            # build localhost/bootc-demo:v1 and show the lint result
./run.sh cleanup    # remove the image
```

Override the base image or name via `common/env` (`BASE_IMAGE`, `IMAGE_NAME`).

## Expected output

- `podman build` completes; the final `RUN bootc container lint` step succeeds.
- The image shows the `containers.bootc=1` (and `ostree.bootable=1`) labels — it's a bootable
  container.
- `bootc container lint` reports **Checks passed: 12, Warnings: 1** and passes. The single
  remaining warning (`var-tmpfiles` on `/var/roothome/buildinfo/content-sets.json`) is inherited
  from the CentOS bootc **base image**, not introduced by this Containerfile — verify with
  `podman run --rm quay.io/centos-bootc/centos-bootc:stream10 ls /var/roothome/buildinfo`. We
  leave base-shipped metadata in place rather than deleting it just to silence the linter.

## What next

- **Demo 02** runs this image as a plain container.
- **Demo 03** boots it as a real host OS in a local VM.
