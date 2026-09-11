#!/usr/bin/bash
# What the image must look like once it has actually booted. Every assertion here exists
# because a container build cannot show it: unit state, the swap topology the kernel
# really assembled, SELinux labels applied at install, and sysctls in effect.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

echo "== boot"

# Without the wait this always reads "starting" and proves nothing.
vm 'systemctl is-system-running --wait' >/dev/null 2>&1 || true
assert_eq "system settled" "running" "$(vm 'systemctl is-system-running')"
assert_eq "no failed units" "" "$(vm 'systemctl --failed --no-legend --plain --no-pager')"

for unit in earlyoom.service notify-oom-kill.service make-swapfile.service \
            var-swap-swapfile.swap uresourced.service; do
    assert_eq "$unit active" "active" "$(vm "systemctl is-active $unit")"
done

# The swapfile must sit below zram, or the compressed RAM this machine is tuned around
# gets bypassed in favour of NVMe.
swaps=$(vm 'swapon --show=NAME,PRIO --noheadings')
assert_match "zram swap at priority 100" '/dev/zram0 +100' "$swaps"
assert_match "disk swapfile at priority 10" '/var/swap/swapfile +10' "$swaps"

assert_eq "/var is btrfs" "btrfs" "$(vm 'findmnt -no FSTYPE --target /var')"
assert_eq "SELinux enforcing" "Enforcing" "$(vm 'getenforce')"

# make-swapfile's own comment calls this untested: whether the label it sets survives and
# swapon accepts it. It does - and this is what keeps it that way.
assert_match "swapfile labelled swapfile_t" 'swapfile_t' "$(vm 'ls -Z /var/swap/swapfile')"

assert_eq "vm.swappiness" "180" "$(vm 'sysctl -n vm.swappiness')"
assert_eq "vm.page-cluster" "0" "$(vm 'sysctl -n vm.page-cluster')"

# uresourced turns files/etc/uresourced.conf into a real cgroup setting, and only for a
# logged-in user - which is why the test image autologins.
assert_eq "user@1000 MemoryMin is 1 GiB" "1073741824" \
          "$(vm 'systemctl show -p MemoryMin --value user@1000.service')"

# The notify-failure wiring itself, so the scenario that exercises the notifier against a
# test unit cannot pass while the shipped units have quietly lost their OnFailure line.
for unit in make-swapfile.service var-swap-swapfile.swap; do
    assert_eq "$unit notifies on failure" "notify-failure@${unit}.service" \
              "$(vm "systemctl show -p OnFailure --value $unit")"
done

finish
