# Demo 04 — Podman Desktop bootc workflow (GUI)

**Consumption mode:** developer workflow — build → disk export → boot VM, all in a GUI.
**Runs on:** the Mac (Apple Silicon), with Podman Desktop + the Bootc extension.

## What this proves

The same build→disk→boot loop from the CLI demos is available as a **one-click GUI** for
engineers who prefer it. The Bootc extension wraps `bootc-image-builder` (disk export) and a
local VM launcher, so you can go from a `Containerfile` to a booted VM without memorizing flags.

## Prerequisites

- **Podman Desktop** installed, with a running Podman machine
  ([download](https://podman-desktop.io/downloads))
- The **Bootc extension** installed (Podman Desktop → *Extensions* → *Catalog* → "Bootc")
  ([docs](https://podman-desktop.io/docs/extensions/bootc-extension))

```bash
./run.sh check   # verify Podman Desktop + machine, then install the Bootc extension in-app
./run.sh         # same checks, build the demo image (if missing), open Podman Desktop
```

> **If podman shows "connection refused" / "Cannot connect to Podman":** the machine went
> stale — restart it and retry:
> ```bash
> podman machine stop && podman machine start
> ```

## Steps (click-through)

1. **Have the image.** Either **build in-app** (*Images → Build* → select
   [`common/Containerfile.base`](../../common/Containerfile.base), build arg `VERSION=v1`, tag
   `localhost/bootc-demo:v1`), or just run `./run.sh` here first — it builds
   `localhost/bootc-demo:v1` (arm64) via the CLI so it already appears in Podman Desktop's
   *Images* list.
2. **Open Bootc → Build a disk.** Left nav → **Bootc** → **Build**. This takes you to the
   **Disk Images** page. Pick `localhost/bootc-demo:v1`, choose:
   - **Type:** QCOW2 (also available: RAW, AMI, ISO, VMDK, VHD)
   - **Platform / architecture:** `arm64` on Apple Silicon — **must match the image's arch**
     (see note below)
   - an **output folder** for the artifact
   then click **Build**. Under the hood this runs `bootc-image-builder`; expect **2–5 min**.
3. **Enter your macOS password when prompted.** bib runs as a *rootful* container, so the
   extension does a `sudo podman run` and asks for credentials mid-build. This is expected.
4. **Provide a login (config.toml).** Base images have **no default user**, so supply a
   **username**, an **SSH public key** and/or **password**, and add the user to the **`wheel`**
   group (for sudo) — the equivalent of
   [`common/config.toml.tmpl`](../../common/config.toml.tmpl). Without this you won't be able to
   log into the VM. No SSH key yet? Generate one and paste the `.pub` contents:
   ```bash
   ls ~/.ssh/id_ed25519.pub 2>/dev/null || ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
   cat ~/.ssh/id_ed25519.pub
   ```
5. **Create the VM.** On the **Disk Images** page, use the **Create VM** button on the produced
   QCOW2 artifact to boot it locally (macOS + Linux supported), then open the console / SSH.
6. **Verify it's a real booted host.** In the VM:
   ```bash
   uname -r                            # the image's own kernel
   cat /proc/1/comm                    # systemd (PID 1 of the machine)
   systemctl is-active httpd           # active
   curl -s http://localhost/           # <h1>bootc demo — v1</h1>
   cat /usr/share/bootc-demo-version   # v1
   sudo bootc status                   # tracked deployment (like demo 03's libvirt path)
   ```

> **Architecture matching:** the bootc OCI image and the disk build must be the **same arch**.
> On Apple Silicon, build an **arm64** image → **arm64** disk (what `./run.sh` does). To target
> x86_64 from an ARM Mac, build with `--platform linux/amd64` and pick `amd64` as the disk
> platform. (Demo 05 builds the **amd64 AMI** for EC2 that way.)

> Screenshots: drop them in `./images/` and reference them here as you record the demo.

## Expected result

A QCOW2 disk is produced (in `output/qcow2/disk.qcow2` under your chosen folder) and a local VM
boots from it via **Create VM** — the GUI equivalent of demos 02–03, no terminal required.

## What next

Demos 05/06 move from local to **real cloud**: build an AMI and run/upgrade it on AWS EC2.
