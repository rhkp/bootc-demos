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
./run.sh         # same checks, then open Podman Desktop
```

## Steps (click-through)

1. **Build the image.** *Images → Build* → select
   [`common/Containerfile.base`](../../common/Containerfile.base). Set build arg `VERSION=v1`
   and tag it `localhost/bootc-demo:v1` (or pull the image you built in demo 01).
2. **Open Bootc.** Left nav → **Bootc** → *Build* → pick `localhost/bootc-demo:v1`.
3. **Export a disk.** Choose output type **QCOW2** (and/or **RAW**), pick the target
   architecture (`arm64` on Apple Silicon), choose an output folder, **Build**. This runs
   `bootc-image-builder` under the hood.
4. **Provide a login.** When prompted, supply a user + SSH key / password (base images have no
   default user) — the extension writes the equivalent of
   [`common/config.toml.tmpl`](../../common/config.toml.tmpl).
5. **Boot a VM.** From the produced artifact, use the extension's **Launch VM** action to boot
   it locally, then open the console / SSH.
6. **Verify.** In the VM: `bootc status`, `systemctl status httpd`,
   `cat /usr/share/bootc-demo-version` → `v1`.

> Screenshots: drop them in `./images/` and reference them here as you record the demo.

## Expected result

A QCOW2 (and/or RAW) disk is produced and a local VM boots from it — the GUI equivalent of
demos 02–03, no terminal required.

## What next

Demos 05/06 move from local to **real cloud**: build an AMI and run/upgrade it on AWS EC2.
