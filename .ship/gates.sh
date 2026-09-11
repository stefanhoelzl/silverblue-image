#!/usr/bin/env bash
set -euo pipefail

# The build only copies these in; nothing runs them until the target machine boots,
# so a syntax error would ship silently. `bash -n` reads one script per call.
for script in files/usr/libexec/* tests/files/usr/libexec/boot-test-helper; do
  bash -n "$script"
done

# The boot test itself only runs in CI (it needs real root for a loop device), so a
# syntax error in it would otherwise surface there rather than here.
for script in tests/*.sh; do
  bash -n "$script"
done

# The build is the test - its final step is `bootc container lint --fatal-warnings`.
podman build -t fedora-silverblue:ship-gate .
