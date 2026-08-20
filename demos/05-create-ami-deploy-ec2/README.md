# Demo 05 — Create an AMI and deploy to a real AWS EC2 VM

**Consumption mode:** converted disk image for the cloud (AMI) → running cloud host OS.
**Runs on:** build on the AWS Linux dev VM, deploy to AWS EC2.

## What this proves

The *same* container image becomes a native **Amazon Machine Image** via
`bootc-image-builder`, and boots as a first-class **cloud host OS** on EC2 — the same OS you ran
as a container (02) and a local VM (03), now in the cloud, with one toolchain instead of a
separate cloud-imaging pipeline.

## How the flow works (read this first)

**`build-ami` both *builds and registers* the AMI in one shot — there is no separate
"register in the console" step.** `bootc-image-builder` converts the container image to a raw
disk, uploads it to your S3 bucket, imports it as an EBS snapshot, and **registers the AMI in
your AWS account** automatically. When the command finishes, the finished `ami-…` simply *appears*
under **EC2 → Images → AMIs** (owned by you) — you don't create it there yourself.

```
[container image]
   │  ./run.sh build-ami   (bootc-image-builder --type ami)
   ▼
raw disk ──upload──▶ S3 bucket ──import──▶ EBS snapshot ──register──▶ AMI  ✅ shows up in Console
   │  ./run.sh launch      (ec2 run-instances --image-id ami-…)
   ▼
running EC2 instance ──▶ ./run.sh ssh ──▶ verify (bootc status, httpd, version)
```

So the sequence is: **build-ami (build **and** register)** → **launch (new instance from that
AMI)** → **ssh** → **cleanup**. The only thing that appears in the console on its own is the
registered AMI; launching from it is the next, separate step (this script does it, or you can use
the console's *Launch from AMI*).

## ⚠️ Costs & credentials

This creates **billable** AWS resources (S3 staging object, an AMI + EBS snapshot, an EC2
instance). Run `./run.sh cleanup` when done.

**To pause between demos without re-uploading:** terminate *just the instance* (stops the compute
charge) but keep the AMI + snapshot — then `./run.sh launch` boots a fresh instance in seconds
with no rebuild. A full `./run.sh cleanup` deregisters the AMI and deletes the snapshot, so coming
back means `build-ami` re-uploads the ~10 GB disk. (Kept snapshot storage is only pennies/day.)

```bash
# terminate instance only, keep the AMI for a quick relaunch later:
aws --region "$AWS_REGION" ec2 terminate-instances --instance-ids "$(cat .instance-id)"
rm -f .instance-id .instance-ip          # .ami-id stays -> ./run.sh launch reuses the AMI
```

Credentials — `run.sh` supports two ways and **stores no keys of its own**:
- **EC2 instance role (recommended when building on an EC2 host):** attach an IAM role to the
  builder instance granting EC2 + S3 access. No `~/.aws` is needed — the host uses the role, and
  the bib container reaches it over IMDS. The script adds `--network host` so the container can
  reach the metadata service (`169.254.169.254`); without it the import step fails silently with
  `http_code=000`. This is how the demo was validated. The role is the *caller* for the whole
  flow, so it needs: S3 `PutObject`/`GetObject`/`ListBucket` on the staging bucket;
  `ec2:ImportSnapshot`/`RegisterImage` for `build-ami`; and `ec2:RunInstances`/`Describe*`/
  `CreateTags`/`TerminateInstances`/`DeregisterImage`/`DeleteSnapshot` for `launch`+`cleanup`. It
  is *distinct from* the `vmimport` service role below.
- **`~/.aws` config:** if `~/.aws` exists, it's mounted read-only into the builder and
  `AWS_PROFILE` is honored.

Everything non-secret (region, bucket, arch, instance type, SG/subnet) is set in `common/env`.

## AWS one-time setup: the `vmimport` service role (easy to miss)

Registering an AMI from a disk uses AWS **VM Import/Export**, which runs under a dedicated service
role named **`vmimport`** — *separate from* the instance role above. That role must be allowed to
read your staging bucket, or `build-ami` fails at the import step with:

```
error: cannot upload AMI: ... ImportSnapshot ... InvalidParameter:
User: arn:aws:sts::<acct>:assumed-role/vmimport/... is not authorized to perform:
s3:GetObject on resource "arn:aws:s3:::<bucket>/..."
```

Ensure the `vmimport` role exists (with the standard `vmie.amazonaws.com` trust + `sts:ExternalId
= vmimport`) and attach an inline policy — e.g. **`rhkp-vmimport-bootc-staging`** — scoped to your
bucket (no account id needed):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket", "s3:PutObject"],
      "Resource": [
        "arn:aws:s3:::YOUR_STAGING_BUCKET",
        "arn:aws:s3:::YOUR_STAGING_BUCKET/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:ModifySnapshotAttribute", "ec2:CopySnapshot", "ec2:RegisterImage", "ec2:Describe*"],
      "Resource": "*"
    }
  ]
}
```

## Prerequisites

- Demo 01 has been run (`localhost/bootc-demo:v1` exists). **Note:** bib runs *rootful* (`sudo`),
  so the image must be in **root's** container storage; `run.sh` copies it there automatically if
  demo 01 built it rootless.
- `podman` (bib runs with `sudo`) and the `aws` CLI, with working credentials — either an EC2
  instance role or `~/.aws` (see *Costs & credentials* above)
- The **`vmimport`** service role with S3 access to the staging bucket (see section above)
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
./run.sh build-ami   # bib --type ami: build + upload to S3 + REGISTER the AMI (appears in Console)
./run.sh launch      # run-instances from the AMI, wait, print the public IP
./run.sh ssh         # SSH in as the baked demo user
./run.sh all         # build-ami + launch
./run.sh cleanup     # terminate instance, deregister AMI, delete snapshot
```

Inside the instance — prove it's a genuine bootc-managed host, not a conventional VM:

```bash
sudo bootc status                   # Booted image: localhost/bootc-demo:v1 + digest (amd64)
findmnt /                           # SOURCE=composefs, FSTYPE=overlay, mounted ro
touch /usr/testfile                 # fails: read-only /usr (transactional OS)
cat /usr/share/bootc-demo-version   # -> v1  (our baked content)
systemctl status httpd              # active  (our baked service)
```

The clincher is `sudo bootc status` reporting `Booted image: localhost/bootc-demo:v1` with a
digest — the machine declaring it runs the *exact container image you built* — combined with a
read-only composefs root. That's the full bootc fingerprint.

## Expected output

- `build-ami` uploads a **~10 GB** disk to S3 and takes several minutes; it then prints a
  registered `ami-...` id. Re-running before cleanup re-uploads the disk (there's no resume).
- `launch` prints a public IP; SSH works only after the OS finishes **first boot** (a minute or
  two) — `run.sh ssh` polls until sshd answers with the baked demo key.
- `ssh` lands you in the VM; `sudo bootc status` shows the booted image + digest.
- **cleanup:** `./run.sh cleanup` terminates the instance, deregisters the AMI, and deletes the
  snapshot — but the **S3 staging object is *not* auto-deleted** (it warns you). Delete it from
  the console (or `aws s3 rm`) to avoid lingering storage charges.

## What next

Demo 06 pushes a **v2** image and performs an **atomic upgrade + rollback** on this running EC2
host — bootc's headline day-2 capability.
