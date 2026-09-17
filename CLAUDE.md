# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Builds a custom Fedora Silverblue container image: RPM Fusion codecs, AMD hardware video
decode, HEIF support, Proton VPN, a few tools, and memory/coredump tuning for zswap in
front of a disk swapfile. Published to GitHub Container Registry and rebased onto with rpm-ostree.

## Repository layout

- `Containerfile` — three commented steps: copy `files/`, one dnf RUN, finalize.
- `files/` — mirrors the image rootfs. Everything under it ships via `COPY files/ /`.
- `files/usr/share/fedora-silverblue/packages.txt` — the package list, also readable on the
  running system as a record of what this image layers.
- `tests/` — the VM boot test: `boot-test.sh` installs the image to a disk and boots
  it, the `assert-*.sh` scenarios drive it over ssh, and `tests/files/` is what the test
  image adds on top of the shipped one.
- `.github/workflows/build.yaml` — `podman build`; boot test on pull requests and on the
  nightly run; pushed to GHCR on `main`.

## Build commands

```bash
podman build -t fedora-silverblue:local .
```

The build is its own test: the final step runs `bootc container lint --fatal-warnings`, so
any lint warning fails it. CI builds on pull requests, on push to `main`, and daily at
15:00 UTC.

The boot test cannot run locally. `bootc install to-disk --via-loopback` needs a loop
device and a btrfs mount, both checked against the initial user namespace, so no rootless
container reaches them however privileged it looks — while a CI runner is simply root.
qemu itself needs no privilege. Locally the build plus lint stays the gate; to run the
boot test against a branch, use `gh workflow run build-image --ref <branch>`.

To check a change against what is currently shipped, build both and diff:

```bash
mkdir -p /tmp/old && git show HEAD:Containerfile > /tmp/old/Containerfile
git archive HEAD files | tar -x -C /tmp/old     # only if files/ changed
podman build -t sb:old /tmp/old && podman build -t sb:new .
diff <(podman run --rm sb:old rpm -qa | sort) <(podman run --rm sb:new rpm -qa | sort)
diff <(podman run --rm sb:old find /etc -type f | sort) \
     <(podman run --rm sb:new find /etc -type f | sort)
```

## Key concepts

- **rpm-ostree / bootc**: Silverblue's base is read-only; customization means layering
  packages into this image. `/var` in the image is copied onto the machine at first
  install, so build leftovers there do ship — hence the `rm -rf` in the packages step.

- **Adding a config file**: create it under `files/` at the path it should occupy in the
  image. No Containerfile change needed. Never write config with `printf` inside a RUN.

- **Adding a package**: append it to `files/usr/share/fedora-silverblue/packages.txt` under
  the right comment group. Comments must be on their own line — a trailing `pkg # why`
  would be passed to dnf. Swaps and anything needing `--allowerasing` stay in the
  Containerfile.

- **One dnf RUN**: all dnf operations stay in a single RUN ending in `dnf5 clean all`,
  because the rpm cache is written into that layer and a later layer cannot delete it.
  This is about cache bloat, not layer count — `COPY` steps are free to be separate.
  Comment lines inside a RUN continuation are fine; the parser strips them, even
  mid-argument-list.

- **Third-party repos**: let upstream's release RPM own the repo config wherever its URL
  never needs editing. RPM Fusion's carries only `$(rpm -E %fedora)`, so it is installed
  in the dnf RUN. Proton VPN's would pin an exact package version (`1.0.4-1`) with no
  "latest" alias, so its repo is a file in `files/etc/yum.repos.d/` instead.

- **Finalizing**: `ostree container commit` canonicalizes `/run` and `/var/cache`;
  `bootc container lint --fatal-warnings` verifies what commit does not fix. Both are
  needed — without commit, lint fails on `/run/dnf` and `/var/cache/*`.

- **No systemctl during the build**: there is no running systemd, so package scriptlets
  calling `systemctl enable` cannot work. This image does not shim systemctl; it avoids
  packages whose scriptlets require it. To enable a unit, ship the wants symlink under
  `files/usr/lib/systemd/system/<target>.wants/` instead.

- **Boot test**: the things a container build cannot show — units reaching active, the
  swap topology the kernel really assembled, SELinux labels applied at install, sysctls
  in effect, uresourced's `MemoryMin` on a real session. It boots `graphical.target` with
  an autologin user because uresourced and both `notify-*` scripts only exist inside a
  session. The out-of-memory scenario runs a large hog *and* a small process with a high
  `oom_score_adj`: asserting the decoy survives is what actually tests `--sort-by-rss`,
  since "something got killed" would pass under the default ranking too. The Retry button is
  deliberately not clicked: emitting `ActionInvoked` from another connection lands on the
  bus but never reaches the waiting `notify-send`, because the bus delivers signals by
  match rule and libnotify's proxy matches the notification daemon's name, which
  gnome-shell owns. The test asserts the notification carries the action and that the
  notifier is still waiting for an answer.

- **Proton VPN**: `proton-vpn-gtk-app` is installed directly rather than the
  `proton-vpn-gnome-desktop` metapackage (which ships no files of its own). The metapackage
  pulls in `proton-vpn-daemon`, whose `%posttrans` scriptlet calls `systemctl` and aborts
  the transaction. That daemon provides only split tunneling — a paid-plan feature — and
  drags in the clang/llvm/bcc toolchain for its eBPF monitor: 18 packages, ~330 MB.
  If the VPN app ever misbehaves, the revert is to restore the metapackage *and* re-add a
  systemctl shim to the dnf RUN; those two changes travel together.
