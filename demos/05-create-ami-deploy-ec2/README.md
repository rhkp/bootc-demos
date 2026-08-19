# Demo 05 — Create an AMI and deploy to a real AWS EC2 VM

**Consumption mode:** converted disk image for the cloud (AMI) → running cloud host OS.
**Runs on:** build on the AWS Linux dev VM, deploy to AWS EC2.

## What this proves

The *same* container image becomes a native **Amazon Machine Image** via
`bootc-image-builder`, and boots as a first-class **cloud host OS** on EC2 — the same OS you ran
as a container (02) and a local VM (03), now in the cloud, with one toolchain instead of a
separate cloud-imaging pipeline.

## ⚠️ Costs & credentials

This creates **billable** AWS resources (S3 staging object, an AMI + EBS snapshot, an EC2
instance). Real credentials come from your `~/.aws` config; everything else is set in
`common/env`. Run `./run.sh cleanup` when done.

## Prerequisites

- Demo 01 has been run (`localhost/bootc-demo:v1` exists)
- `podman` (bib runs with `sudo`), `aws` CLI configured (`aws sts get-caller-identity` works)
- `common/env` filled in: `AWS_REGION`, `S3_BUCKET` (must already exist), `INSTANCE_TYPE`,
  `AMI_ARCH`, and optionally `EC2_KEY_NAME`/`EC2_SECURITY_GROUP`/`EC2_SUBNET_ID`
- **Arch match:** `AMI_ARCH` must match `INSTANCE_TYPE` (e.g. `amd64`+`t3.small`, or
  `arm64`+`t4g.small`)

> **Login note (important):** the generic bootc base has **no cloud-init**, so the usual EC2
> key-pair injection does *not* apply. This demo **bakes** a `demo` user + a generated SSH key
> into the image via [`common/config.toml.tmpl`](../../common/config.toml.tmpl) and logs in with
> that key (`demos/05-.../.demo-keys/`). Make sure the instance's **security group allows inbound
> TCP 22** from your IP.

## Run

```bash
./run.sh build-ami   # bib --type ami: upload to S3 + register the AMI
./run.sh launch      # run-instances from the AMI, wait, print the public IP
./run.sh ssh         # SSH in as the baked demo user
./run.sh all         # build-ami + launch
./run.sh cleanup     # terminate instance, deregister AMI, delete snapshot
```

Inside the instance:

```bash
bootc status                        # tracked image + digest on a real cloud host
systemctl status httpd
cat /usr/share/bootc-demo-version   # -> v1
```

## Expected output

- `build-ami` prints a registered `ami-...` id.
- `launch` prints a public IP; `ssh` lands you in the VM; `bootc status` shows the image.

## What next

Demo 06 pushes a **v2** image and performs an **atomic upgrade + rollback** on this running EC2
host — bootc's headline day-2 capability.
