FROM quay.io/fedora/fedora-silverblue:latest

# --- files ---
# files/ mirrors the image rootfs: repo definitions, sysctl and systemd drop-ins, and the
# package list read by the next step. Adding config needs no change to this file.
COPY files/ /

# --- packages ---
# Every dnf operation stays in this one RUN: the rpm cache it writes into this layer cannot
# be removed by a `dnf5 clean all` in a later one.
#
# RPM Fusion is enabled by its release RPM because that URL never needs editing — it carries
# only $releasever. Proton VPN's equivalent would pin an exact package version, so its repo
# is a file in files/etc/yum.repos.d/ instead.
RUN dnf5 -y install \
      https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm && \
    # replace Fedora's stripped-down codecs with the RPM Fusion builds
    dnf5 -y swap noopenh264 openh264 && \
    dnf5 -y swap ffmpeg-free ffmpeg --allowerasing && \
    # AMD hardware H.264/HEVC decode
    dnf5 -y install mesa-va-drivers-freeworld --allowerasing && \
    dnf5 -y install $(grep -hv '^#' /usr/share/fedora-silverblue/packages.txt) && \
    dnf5 clean all && \
    # /var in the image is copied onto the machine at first install, so dnf's leftovers
    # there would ship. `ostree container commit` below clears /var/cache but not these.
    rm -rf /var/log/dnf5.log /var/lib/dnf && \
    # files/etc/default/earlyoom replaces an rpm %config(noreplace) file, so installing
    # earlyoom drops its own copy alongside as .rpmnew. Nothing reads it; don't ship it.
    rm -f /etc/default/earlyoom.rpmnew

# --- finalize ---
# commit canonicalizes /run and /var/cache; lint verifies what commit does not fix. Both are
# needed: without commit, lint fails on /run/dnf and /var/cache/*.
RUN ostree container commit && \
    bootc container lint --fatal-warnings
