# Demo 06 — Day-2 atomic upgrade + rollback on the EC2 host

**Consumption mode:** running-host lifecycle — `bootc upgrade` / `switch` / `rollback`.
**Runs on:** the EC2 instance from demo 05 (bootc commands run there over SSH); images are
built and pushed from the dev VM.

## What this proves

bootc's headline value: OS updates are **atomic OCI image swaps**, staged in the background and
applied on reboot, with **instant rollback** to the previous known-good deployment. This is how
you eliminate configuration drift and manage a fleet with GitOps — demonstrated on a *real cloud
host*.

The flow: the EC2 host starts **tracking a registry tag**, you push a **v2** image to that tag,
`bootc upgrade` pulls it (detected by **manifest digest**, not tag string), reboots into v2, and
`bootc rollback` returns to v1.

## Prerequisites

- Demo 05 has run and left a **running EC2 instance** (`demos/05-.../.instance-ip` +
  `.demo-keys/`)
- `REGISTRY` set in `common/env` to a registry the EC2 host can pull from
  (e.g. `quay.io/<you>`, `ghcr.io/<you>`, or an ECR URI). Set this in the *live, gitignored*
  `common/env` — not in any committed sample.
- You are logged in **with push/write permission**: `podman login <registry>`. A read-only or
  expired credential still authenticates but fails at the *end* of the push with
  `unauthorized: access to the requested resource is not authorized` — all layers upload, then the
  final manifest write is rejected. On Quay use a **CLI/encrypted password** or a **robot account
  with Write**.
- **Repo visibility:** the first `push-v1` auto-creates the repo, and Quay defaults new repos to
  **private**. The EC2 host pulls **anonymously** during `adopt`/`upgrade`, so either make the
  repo **Public** (simplest — Repository → Settings → Make Public) *or* place pull auth in
  `/etc/ostree/auth.json` on the host for a private repo.
- The EC2 host has outbound access to the registry.

## Why "adopt" first

Demo 05's AMI was built from a **local** image ref, so the deployed host isn't yet tracking your
registry. `adopt` runs `bootc switch --apply <registry>/<image>:latest` to make the host track
the registry tag (still v1), and **disables `bootc-fetch-apply-updates.timer`** so automatic
updates can't silently undo the manual rollback you're about to demo.

## Run

```bash
./run.sh push-v1     # build v1, push :v1 + :latest to $REGISTRY
./run.sh adopt       # EC2 host -> track $REGISTRY/<image>:latest (reboots); disables auto-timer
./run.sh push-v2     # build v2 (changed page/stamp), push :v2 + :latest
./run.sh upgrade     # on EC2: bootc upgrade --check then --apply (reboots into v2)
./run.sh status      # on EC2: bootc status + served page
./run.sh rollback    # on EC2: bootc rollback --apply (reboots back to v1)
./run.sh all         # the whole sequence end to end
```

## Expected output

`bootc status` transitions across the run:

- after `adopt`  → **Booted** `…:latest` (v1), version stamp `v1`
- after `upgrade` → **Booted** digest changes, version stamp `v2`, page reads `bootc demo — v2`,
  previous v1 shown as **Rollback**
- after `rollback` → **Booted** back to the v1 digest, page reads `bootc demo — v1`

The changing **digests** in `bootc status` are the proof of the atomic swap.

## Notes / gotchas (validated)

- **Track a tag, not a digest** — switching to an explicit `@sha256:…` makes `bootc upgrade` a
  permanent no-op.
- **`--apply` reboots.** The script waits for SSH to come back after each step.
- **Auto-update timer** is disabled by `adopt`; re-enable with
  `sudo systemctl enable --now bootc-fetch-apply-updates.timer` when you're done.
- **HTTP/insecure registry** (only if you use one instead of a TLS registry): bake
  `/etc/containers/registries.conf.d/*.conf` with `insecure = true` into the image.

## Cleanup

Nothing new to remove here. Tear down the cloud resources with demo 05's
`./run.sh cleanup`, and delete the pushed tags from your registry if you wish.
