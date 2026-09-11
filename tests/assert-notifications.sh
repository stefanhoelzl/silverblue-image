#!/usr/bin/bash
# notify-failure: a failing unit reaches the desktop, offering the Retry button rather
# than just text.
#
# The click itself is deliberately NOT simulated. Emitting ActionInvoked from another
# connection puts the signal on the bus but does not reach the waiting notify-send: the
# bus delivers signals by match rule, and libnotify's proxy matches on the notification
# daemon's name, which gnome-shell owns. Measured, not assumed - the signal reaches the
# bus and the notifier never acts on it. Invoking it for real would mean owning
# org.freedesktop.Notifications with a stub, which would then be the thing under test
# instead of the daemon this image actually runs.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

echo "== notifications"

vm '/usr/libexec/boot-test-helper notify-watch'

# Designed to fail, so this returns non-zero.
vm 'systemctl start boot-test-failure.service' >/dev/null 2>&1 || true

notified() { vm "/usr/libexec/boot-test-helper notify-trace | grep -q 'boot-test-failure.service failed'"; }
if ! wait_for 120 notified; then
    fail "no notification for the failed unit within 120s"
    finish
fi
ok "failed unit raised a desktop notification"

trace=$(vm '/usr/libexec/boot-test-helper notify-trace')
assert_match "notification offers the Retry action" '"retry", *"Retry"' "$trace"

# The notifier's own account of what it did. Asserting instead that it is *still*
# blocked on the click would be racing the desktop: whether the notification is still
# open depends on the daemon, not on this image.
assert_match "notify-failure found the session and notified it" \
             'notifying .+ about boot-test-failure.service' \
             "$(vm 'journalctl -t notify-failure -o cat --no-pager')"

finish
