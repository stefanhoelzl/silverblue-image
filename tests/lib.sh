# Shared by the boot-test scenarios. Sourced, never executed.
#
# Scenarios report every assertion and never exit early, so one failure does not hide
# the ones after it; boot-test.sh collects the exit codes.

SSH_PORT=${SSH_PORT:-2222}
TEST_USER=tester
TEST_UID=1000

ssh_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o LogLevel=ERROR -o ConnectTimeout=5)

# Run a command in the VM as root. Takes a single string, handed to the guest's shell -
# quote inside it exactly as you would for `bash -c`.
vm() { ssh "${ssh_opts[@]}" -i "$SSH_KEY" -p "$SSH_PORT" root@127.0.0.1 "$*"; }

# Run a command as the autologin user, on that user's session bus. The user manager is a
# separate world: `systemctl --failed` as root cannot see a failed portal or shell.
vm_user() {
    vm "runuser -u $TEST_USER -- env XDG_RUNTIME_DIR=/run/user/$TEST_UID" \
       "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$TEST_UID/bus $*"
}

FAILURES=0
ok()   { printf '  ok    %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*" >&2; FAILURES=$(( FAILURES + 1 )); }

assert_eq() {  # <description> <expected> <actual>
    if [[ "$2" == "$3" ]]; then ok "$1"; else fail "$1 - expected '$2', got '$3'"; fi
}

assert_match() {  # <description> <extended regex> <text>
    if grep -Eq -- "$2" <<<"$3"; then ok "$1"; else fail "$1 - /$2/ did not match: $3"; fi
}

# Retry until the command succeeds or the budget runs out.
wait_for() {  # <seconds> <command...>
    local deadline=$(( SECONDS + $1 )); shift
    until "$@"; do
        (( SECONDS < deadline )) || return 1
        sleep 2
    done
}

finish() {  # every scenario ends with this
    (( FAILURES == 0 )) || echo "  ${FAILURES} failed assertion(s)" >&2
    exit $(( FAILURES > 0 ))
}
