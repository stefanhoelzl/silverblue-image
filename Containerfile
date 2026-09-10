FROM quay.io/fedora/fedora-silverblue:latest

RUN printf '%s\n' \
    '[protonvpn-stable]' \
    'name=Proton VPN Fedora Stable repository' \
    'baseurl=https://repo.protonvpn.com/fedora-$releasever-stable' \
    'enabled=1' \
    'gpgcheck=1' \
    'gpgkey=https://repo.protonvpn.com/fedora-$releasever-stable/public_key.asc' \
    > /etc/yum.repos.d/protonvpn-stable.repo && \
    cp -a /usr/bin/systemctl /usr/bin/systemctl.real && \
    ln -sf /usr/bin/true /usr/bin/systemctl && \
    dnf5 -y install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm && \
    dnf5 -y swap noopenh264 openh264 && \
    dnf5 -y swap ffmpeg-free ffmpeg --allowerasing && \
    dnf5 -y install mesa-va-drivers-freeworld --allowerasing && \
    dnf5 -y install gstreamer1-plugin-openh264 mozilla-openh264 powertop \
    libheif-freeworld heif-pixbuf-loader libheif-tools podman-compose \
    proton-vpn-gnome-desktop gnome-shell-extension-appindicator && \
    rm -f /usr/bin/systemctl && \
    mv /usr/bin/systemctl.real /usr/bin/systemctl && \
    mkdir -p /etc/sysctl.d /etc/systemd/oomd.conf.d /etc/systemd/coredump.conf.d && \
    printf '%s\n' \
    '# zram-only swap: prefer compressing anonymous pages over evicting' \
    '# file-backed (incl. executable) pages, and skip swap readahead.' \
    'vm.swappiness=180' \
    'vm.page-cluster=0' \
    > /etc/sysctl.d/90-zram-tuning.conf && \
    printf '%s\n' \
    '[OOM]' \
    'DefaultMemoryPressureDurationSec=5s' \
    > /etc/systemd/oomd.conf.d/90-fast-reaction.conf && \
    printf '%s\n' \
    '[Coredump]' \
    'MaxUse=200M' \
    > /etc/systemd/coredump.conf.d/90-max-use.conf && \
    dnf5 clean all && \
    ostree container commit
