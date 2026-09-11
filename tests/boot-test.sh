#!/usr/bin/bash
# Boot the built image in a VM and run the scenarios against it.
#
# Must run as root, and therefore only in CI: `bootc install to-disk --via-loopback`
# needs a loop device and a btrfs mount, and both are checked against the initial user
# namespace - no rootless container can reach them however privileged it looks. qemu
# itself needs nothing. Locally, `podman build` plus `bootc container lint` stay the
# gate; this is what runs on pull requests and on the nightly build.
#
# Usage: sudo tests/boot-test.sh <image>

set -euo pipefail

readonly IMAGE=${1:?usage: boot-test.sh <image>}
readonly HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly TEST_IMAGE=localhost/fedora-silverblue:boot-test
readonly SSH_PORT=2222
# Large enough that make-swapfile's headroom check passes and it really creates the
# 32 GiB file. It costs almost nothing: the image is sparse and btrfs writes the
# swapfile as preallocated-but-unwritten extents.
readonly DISK_SIZE=60G
readonly VM_MEM=4096

WORK=$(mktemp -d)
readonly WORK
export SSH_KEY="$WORK/id"
export SSH_PORT
QEMU_PID=""

cleanup() {
    local rc=$?
    [[ -n $QEMU_PID ]] && kill "$QEMU_PID" 2>/dev/null
    # The console is the only witness to anything that breaks before sshd is up, where
    # the symptom is otherwise just a connection timeout.
    if (( rc != 0 )) && [[ -f $WORK/console.log ]]; then
        echo "=== serial console (last 80 lines) ==="
        sed 's/\x1b\[[0-9;]*m//g' "$WORK/console.log" | tail -80
    fi
    rm -rf "$WORK"
    exit $rc
}
trap cleanup EXIT

echo "== building the test image"
ssh-keygen -q -t ed25519 -N "" -f "$SSH_KEY"
mkdir -p "$WORK/keys" && cp "$SSH_KEY.pub" "$WORK/keys/authorized_keys"
podman build -q -t "$TEST_IMAGE" --build-arg "BASE=$IMAGE" "$HERE" >/dev/null

echo "== installing to a disk image"
# GitHub runners boot without the loop module, so no /dev/loopN exists until asked for.
modprobe loop
truncate -s "$DISK_SIZE" "$WORK/disk.raw"
podman run --rm --privileged --pid=host \
    -v /var/lib/containers:/var/lib/containers \
    -v /dev:/dev \
    -v "$WORK:/var/out" \
    "$TEST_IMAGE" bootc install to-disk \
        --via-loopback --wipe --filesystem btrfs --generic-image \
        --karg console=ttyS0,115200n8 \
        --root-ssh-authorized-keys /var/out/keys/authorized_keys \
        /var/out/disk.raw >/dev/null

echo "== booting"
ovmf_code=/usr/share/OVMF/OVMF_CODE_4M.fd
ovmf_vars=/usr/share/OVMF/OVMF_VARS_4M.fd
[[ -f $ovmf_code ]] || ovmf_code=/usr/share/OVMF/OVMF_CODE.fd
[[ -f $ovmf_vars ]] || ovmf_vars=/usr/share/OVMF/OVMF_VARS.fd
cp "$ovmf_vars" "$WORK/vars.fd"

# romfile= because nothing here PXE boots, and skipping the option ROM drops the
# dependency on ipxe-qemu - only a Recommends of qemu-system-x86, and the package set this
# job installs is the part of it that has been slow.
qemu-system-x86_64 -accel kvm -m "$VM_MEM" -smp 4 -nographic -no-reboot \
    -drive "if=pflash,format=raw,readonly=on,file=$ovmf_code" \
    -drive "if=pflash,format=raw,file=$WORK/vars.fd" \
    -drive "file=$WORK/disk.raw,format=raw,if=virtio" \
    -netdev user,id=net0,hostfwd="tcp::$SSH_PORT-:22" \
    -device virtio-net-pci,netdev=net0,romfile= \
    </dev/null >"$WORK/console.log" 2>&1 &
QEMU_PID=$!

for _ in $(seq 1 150); do
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        -o ConnectTimeout=5 -i "$SSH_KEY" -p "$SSH_PORT" root@127.0.0.1 true 2>/dev/null && break
    kill -0 "$QEMU_PID" 2>/dev/null || { echo "qemu exited during boot" >&2; exit 1; }
    sleep 2
done

failed=0
for scenario in assert-boot assert-oom assert-notifications; do
    "$HERE/$scenario.sh" || failed=1
done

(( failed == 0 )) && echo "== all scenarios passed"
exit $failed
