#!/usr/bin/env bash
set -euo pipefail

# The build only copies these in; nothing runs them until the target machine boots,
# so a syntax error would ship silently. `bash -n` reads one script per call.
for script in files/usr/libexec/*; do
  bash -n "$script"
done

# The build is the test - its final step is `bootc container lint --fatal-warnings`.
podman build -t fedora-silverblue:ship-gate .
