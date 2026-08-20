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
- An **ed25519 SSH key** at `~/.ssh/id_ed25519` — the VM launcher (`macadam`) **only supports
  ed25519**. Generate one if needed: `ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519`

```bash
./run.sh check   # verify Podman Desktop + machine + ed25519 key; install the Bootc extension in-app
./run.sh         # same checks, build both demo images, open Podman Desktop
```

> **If podman shows "connection refused" / "Cannot connect to Podman":** the machine went
> stale — restart it and retry:
> ```bash
> podman machine stop && podman machine start
> ```

## Why a demo-04 overlay image (important)

"Create VM" on macOS uses **`macadam`** (Apple Virtualization Framework). It injects the login
user + your SSH key at first boot via a **cloud-init** seed. **The base `centos-bootc` image
ships no cloud-init (and no ignition)** — so the seed is ignored, the VM boots with no user/key,
and the extension can't SSH in (that's the whole way it reaches the VM). Symptom:
`open ~/.ssh/…: no such file` at create time, or a VM that's created but never usable.

The fix is [`Containerfile`](./Containerfile) — a thin overlay adding `cloud-init` on top of the
demo-01 image, tagged **`localhost/bootc-demo:v1-desktop`**. `./run.sh` builds it for you. **Build
the disk from `:v1-desktop`, not the plain `:v1`.**

## Steps (click-through)

1. **Build both images.** Run `./run.sh` here — it builds `localhost/bootc-demo:v1` and the
   cloud-init overlay `localhost/bootc-demo:v1-desktop` (arm64), so both appear in Podman
   Desktop's *Images* list.
2. **Open Bootc → Build a disk.** Left nav → **Bootc** → **Build** (the **Disk Images** page).
   Pick **`localhost/bootc-demo:v1-desktop`**, choose:
   - **Type:** QCOW2 (also available: RAW, AMI, ISO, VMDK, VHD)
   - **Platform / architecture:** `arm64` on Apple Silicon — **must match the image's arch**
   - an **output folder**
   then **Build**. Runs `bootc-image-builder`; expect **2–5 min**.
3. **Enter your macOS password when prompted.** bib runs as a *rootful* container
   (`sudo podman run`); this is expected.
4. **Create the VM.** On the **Disk Images** page, click **Create VM** on the produced QCOW2.
   macadam seeds your `~/.ssh/id_ed25519.pub` via the cloud-init NoCloud seed at first boot, so
   the VM comes up with a working **root** login (no separate user needed). (First VM op installs
   the `macadam` binary — one more password prompt.)
5. **Start it and open a terminal.** In Podman Desktop, the VM appears under
   **Settings → Resources** (not a separate "VM list"). Click **Start**, then open its
   **terminal** — it drops you into a `root@localhost` shell over SSH.

   > **The CLI `macadam start`/`ssh` will *not* work out of the box** — it fails with
   > `could not find "gvproxy" in one of [...]` because macadam searches `../libexec/podman`
   > relative to its own binary, not its own `bin/` (where `gvproxy` actually ships). **Start from
   > the GUI**, which launches macadam with the right paths. To enable the CLI too, point
   > macadam's helper lookup at the dir holding `gvproxy` (add under the `[engine]` table in
   > `~/.config/containers/containers.conf`):
   > ```toml
   > [engine]
   > helper_binaries_dir = ["/opt/macadam/bin", "/opt/podman/bin"]
   > ```
   > then: `/opt/macadam/bin/macadam list && /opt/macadam/bin/macadam ssh <name>`.
6. **Verify it's a real booted host.** In the VM (you're already root):
   ```bash
   uname -r                            # e.g. 6.12.0-253.el10.aarch64 — the image's own kernel
   cat /proc/1/comm                    # systemd (PID 1 of the machine, not a container)
   systemctl is-active httpd           # active
   curl -s http://localhost/           # <h1>bootc demo — v1</h1>
   cat /usr/share/bootc-demo-version   # v1
   bootc status                        # Booted image: localhost/bootc-demo:v1-desktop (arm64)
   ```

> **Architecture matching:** the bootc OCI image and the disk build must be the **same arch**.
> On Apple Silicon, build an **arm64** image → **arm64** disk. To target x86_64 from an ARM Mac,
> build with `--platform linux/amd64` and pick `amd64` as the disk platform. (Demo 05 builds the
> **amd64 AMI** for EC2 that way.)

> **Console-login alternative:** if you'd rather log in at a console than via macadam's SSH, bake
> a password into the overlay instead of relying on cloud-init — e.g. add
> `RUN echo "root:<pw>" | chpasswd` (hello-world only). The cloud-init path above is cleaner and
> keeps no credential in the image.

> Screenshots: drop them in `./images/` and reference them here as you record the demo.

## Expected result

A QCOW2 disk is produced (`output/qcow2/disk.qcow2` under your chosen folder) and a local VM
boots from it via **Create VM**, reachable over SSH — the GUI equivalent of demos 02–03.

## What next

Demos 05/06 move from local to **real cloud**: build an AMI and run/upgrade it on AWS EC2.
