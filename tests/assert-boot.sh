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

# The swapfile must be the only swap. A zram device left beside it would take every page
# ahead of zswap and put back the full-zram, fresh-pages-to-disk inversion zswap replaces.
assert_eq "disk swapfile is the only swap" "/var/swap/swapfile" \
          "$(vm 'swapon --show=NAME --noheadings')"
# zswap.conf is only a request to tmpfiles; read back what the kernel accepted, since a
# refused write (SELinux on sysfs, the zstd module not loading) leaves lzo or zswap off.
assert_eq "zswap enabled" "Y" "$(vm 'cat /sys/module/zswap/parameters/enabled')"
assert_eq "zswap compressor" "zstd" "$(vm 'cat /sys/module/zswap/parameters/compressor')"

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

# The user manager, which the checks above cannot reach. Both GIO drop-ins exist to keep a
# *user* unit from failing: when xdg-desktop-portal self-calls, it burns four 25s D-Bus
# timeouts, overruns TimeoutStartSec=45s, and GDM bounces the login back to the greeter.
assert_eq "test user has an active session" "active" \
          "$(vm 'loginctl show-user tester --value -p State')"
assert_eq "no failed user units" "" \
          "$(vm_user 'systemctl --user --failed --no-legend --plain --no-pager')"
assert_eq "xdg-desktop-portal came up" "active" \
          "$(vm_user 'systemctl --user is-active xdg-desktop-portal.service')"
# The pins themselves, so the drop-ins are proven in force rather than merely present: an
# unknown GIO module name does not fail loudly, it warns and falls back to the portal.
assert_match "portal pinned off its own backends" 'GIO_USE_PROXY_RESOLVER=gnome' \
             "$(vm_user 'systemctl --user show -p Environment --value xdg-desktop-portal.service')"

# Ask which shell instance is running and assert against that one. `systemctl show` will
# happily report merged config for an instance that was never started, so naming a guess
# here would pass whether or not the shell is pinned.
shell_unit=$(vm '/usr/libexec/boot-test-helper shell-unit')
if [[ -z $shell_unit ]]; then
    fail "no org.gnome.Shell instance is running"
else
    ok "gnome-shell came up as $shell_unit"
    assert_match "gnome-shell pinned off the portal backends" 'GIO_USE_PROXY_RESOLVER=gnome' \
                 "$(vm_user "systemctl --user show -p Environment --value $shell_unit")"
fi

# Syntax only - no VM can show the uaccess ACL reaching an Apple device - but a rules file
# that fails to parse stays silent until something is plugged in.
shopt -s nullglob
for rules in "$(dirname "$0")"/../files/usr/lib/udev/rules.d/*.rules; do
    name=$(basename "$rules")
    assert_match "udev rules $name parse" 'Fail: +0' \
                 "$(vm "udevadm verify /usr/lib/udev/rules.d/$name 2>&1")"
done

# The notify-failure wiring itself, so the scenario that exercises the notifier against a
# test unit cannot pass while the shipped units have quietly lost their OnFailure line.
for unit in make-swapfile.service var-swap-swapfile.swap; do
    assert_eq "$unit notifies on failure" "notify-failure@${unit}.service" \
              "$(vm "systemctl show -p OnFailure --value $unit")"
done

finish
