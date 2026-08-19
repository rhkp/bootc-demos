# Demo 03 — Run the bootc image as a host OS in a local VM

**Consumption mode:** Installing in a Virtual Machine (booted host OS).
**Runs on:** the AWS Linux dev VM. **Requires KVM / nested virtualization.**

## What this proves

The same image now **boots as a real operating system**: it loads *its own* bundled kernel,
`systemd` runs as **PID 1 of the machine** (not inside a container namespace), `/usr` is mounted
read-only from an OSTree/composefs deployment, and `bootc status` reports the tracked image.
Contrast this directly with demo 02, where the identical image ran as a namespaced container on
the host kernel.

We use [`bcvk`](https://github.com/bootc-dev/bcvk) ("bootc virtualization kit") — the maintained
tool for launching bootc containers as VMs on Linux.

> **Why not on the Mac?** `bcvk` is Linux-only today and its predecessor `podman-bootc` is
> archived — so the clean CLI VM path lives on the Linux dev VM. The Mac path is the GUI
> workflow in demo 04.

## Prerequisites

- Demo 01 has been run (image `localhost/bootc-demo:v1` exists)
- `bcvk`, `podman`, `qemu-kvm`, `virtiofsd`; `libvirt` running for the persistent path
- **KVM:** `ls -l /dev/kvm` must exist and be accessible. On AWS that means a `*.metal` or
  nested-virt-capable instance. **No KVM → skip this demo**; demo 05 boots a real cloud host.

This demo builds a thin overlay ([`Containerfile`](./Containerfile)) adding the tools `bcvk
ephemeral` expects in the target image (`binutils`, `bubblewrap`, `openssh-*`).

## Run

```bash
./run.sh check        # verify KVM + bcvk before you start
./run.sh ephemeral    # throwaway VM + auto-SSH (tears down on logout)  [default]
./run.sh libvirt      # persistent named VM
./run.sh ssh          # SSH into the persistent VM
./run.sh cleanup      # remove the persistent VM + overlay image
```

Inside the VM, confirm it's a booted bootc host:

```bash
bootc status                 # shows the booted image + digest
systemctl status httpd       # enabled service is running under host systemd
cat /usr/share/bootc-demo-version   # -> v1
uname -r                     # the image's OWN kernel (was inert in demo 02)
```

## Expected output

- `bcvk` builds a disk, boots a VM, and drops you into an SSH session.
- `bootc status` shows `localhost/bootc-demo:v1-bcvk`; `httpd` is active; `/usr` is read-only.

## What next

- Demo 04 shows the same build→disk→boot loop through the Podman Desktop GUI on a Mac.
- Demos 05/06 take it to real cloud hosts.
