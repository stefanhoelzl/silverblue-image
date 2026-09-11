#!/usr/bin/bash
# The out-of-memory path end to end: earlyoom picks a victim, notify-oom-kill parses the
# kill out of the journal, and the desktop hears about it.
#
# The victim choice is the assertion that matters. A test that only proved "something got
# killed" would pass just as well with stock oom_score ranking; this one runs a decoy
# that the default ranking would kill first and requires it to survive, which is exactly
# what --sort-by-rss buys.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

echo "== out of memory"

# earlyoom announces its thresholds at startup with the words "sending SIGTERM when...",
# so the pattern has to insist on the "to process <pid>" that only a real kill carries.
readonly KILL_LINE='sending SIG[A-Z]+ to process [0-9]+'

vm '/usr/libexec/boot-test-helper notify-watch'
vm '/usr/libexec/boot-test-helper oom-start'

earlyoom_fired() { vm "journalctl -u earlyoom.service -o cat --no-pager | grep -qE '$KILL_LINE'"; }
if ! wait_for 180 earlyoom_fired; then
    fail "earlyoom killed nothing within 180s"
    echo "  --- earlyoom journal ---"
    vm 'journalctl -u earlyoom.service -o cat --no-pager | tail -5'
    vm '/usr/libexec/boot-test-helper oom-stop'
    finish
fi

kill_line=$(vm "journalctl -u earlyoom.service -o cat --no-pager | grep -E '$KILL_LINE' | tail -1")
assert_match "earlyoom killed the large-RSS hog" 'boot-test-hog' "$kill_line"
assert_eq "small high-adj decoy survived" "active" "$(vm 'systemctl is-active boot-test-decoy.service')"

# Nothing else covers this regex. If it stops matching, kills stop being reported and the
# only symptom is silence.
assert_match "notify-oom-kill parsed the kill" '^notify-oom-kill: SIG[A-Z]+ .+ \(pid [0-9]+, [0-9-]+ MiB\)' \
             "$(vm "journalctl -u notify-oom-kill.service -o cat --no-pager | grep '^notify-oom-kill: SIG' | tail -1")"

assert_match "the kill reached the desktop" 'Out of memory: killed' \
             "$(vm '/usr/libexec/boot-test-helper notify-trace')"

vm '/usr/libexec/boot-test-helper oom-stop'
finish
