# Demo 02 — Run the bootc image as a plain container

**Consumption mode:** Standard Container (docker / podman).
**Runs on:** the AWS Linux dev VM (or any Linux with `podman`).

## What this proves

The *same* image that boots as an OS in later demos also runs as an ordinary container. When
run this way (per the brief):

- it uses the **host's kernel** — the kernel bundled in `/usr/lib/modules` is inert;
- with `--systemd=always`, **systemd runs as PID 1 *inside* the container namespace**, not as
  the host init;
- the root filesystem is an ephemeral **OverlayFS** layer, not an OSTree deployment.

This mode is the fast inner-loop for bootc: **package/config inspection and CI linting** with
no VM and no reboot.

## Prerequisites

- Demo 01 has been run (image `localhost/bootc-demo:v1` exists)
- `podman`, and `curl` for the web sub-demo

## Run

```bash
./run.sh            # inspection walkthrough: shared kernel, packages, CI lint
./run.sh web        # start httpd via systemd-in-container, curl http://localhost:8080
./run.sh cleanup    # stop/remove the web container
```

## Expected output

- `inspect`: prints the host kernel, the (inert) bundled kernel modules, `httpd` version, the
  `/var/www -> /usr/share/www` symlink, and a passing `bootc container lint`.
- `web`: `curl http://localhost:8080/` returns the demo page (`bootc demo — v1`).

## What next

Demo 03 boots this identical image as a real host OS (systemd as the *host's* PID 1, bundled
kernel now active).
