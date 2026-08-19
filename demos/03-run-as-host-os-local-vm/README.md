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
- `bcvk`, `podman`, `qemu-system-x86_64`, `virtiofsd` (and `swtpm`); `libvirt` for the persistent
  path
- **KVM:** `ls -l /dev/kvm` must exist and be accessible. On AWS this now means a **nested-virt
  capable Intel instance** — `c7i`/`m7i`/`r7i`/`c8i`/… launched (or reconfigured while stopped)
  with `NestedVirtualization=enabled` — *or* a `*.metal` instance. Older families (e.g. `c5`) and
  Graviton/AMD don't qualify. **No KVM → skip this demo**; demo 05 boots a real cloud host.

### Setup (one-time, per distro)

**Fedora / RHEL / CentOS (EPEL):**
```bash
sudo dnf install -y bcvk qemu-kvm virtiofsd swtpm
```

**Debian / Ubuntu** (`bcvk` isn't packaged — install the release binary):
```bash
sudo apt-get install -y qemu-system-x86 qemu-utils virtiofsd swtpm
ver=v0.18.0
curl -fsSLO https://github.com/bootc-dev/bcvk/releases/download/$ver/bcvk-x86_64-unknown-linux-gnu.tar.gz
tar -xzf bcvk-x86_64-unknown-linux-gnu.tar.gz
sudo install -m0755 bcvk-x86_64-unknown-linux-gnu /usr/local/bin/bcvk
```

**Both — grant KVM access for rootless bcvk:**
```bash
sudo usermod -aG kvm "$USER"      # then re-login so the group takes effect
```
`bcvk` runs QEMU inside a *rootless* podman container, which does **not** inherit your host `kvm`
group by default — so the containerized QEMU fails with `KVM device not accessible` even though
you can open `/dev/kvm`. Fix it globally by preserving host groups in containers:
```bash
mkdir -p ~/.config/containers
cat >> ~/.config/containers/containers.conf <<'EOF'
[containers]
annotations = ["run.oci.keep_original_groups=1"]
EOF
```
`./run.sh check` verifies all of the above before you start.

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

Inside the VM, confirm it's a booted host:

```bash
uname -r                     # the image's OWN kernel (was inert in demo 02)
cat /proc/1/comm             # -> systemd  (PID 1 of the machine)
systemctl is-active httpd    # -> active   (enabled service started on boot)
curl -s http://localhost/    # -> the v1 page
cat /usr/share/bootc-demo-version   # -> v1
```

You can also run a single command non-interactively (boots, runs, tears down):

```bash
bcvk ephemeral run-ssh localhost/bootc-demo:v1-bcvk -- uname -r
```

## Expected output

`ephemeral` boots the image and (validated on a `c7i.2xlarge`) reports:

```
kernel: 6.12.0-253.el10.x86_64     # the image's CentOS kernel, not the host's
pid1:   systemd
httpd:  active
page:   <h1>bootc demo — v1</h1>
```

> **Note on `bootc status`:** in `ephemeral` mode `bcvk` boots the image's filesystem *directly*
> as a transient disk, so `bootc status` is empty (there's no installed/tracked deployment). The
> full deployment status (booted image + digest, `/usr` read-only, rollback slot) is what the
> **persistent `libvirt` path** and **demo 05** (real install on EC2) show.

## What next

- Demo 04 shows the same build→disk→boot loop through the Podman Desktop GUI on a Mac.
- Demos 05/06 take it to real cloud hosts.
