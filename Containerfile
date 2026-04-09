FROM quay.io/fedora/fedora-silverblue:latest

RUN dnf5 -y install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm && \
    dnf5 -y swap noopenh264 openh264 && \
    dnf5 -y install gstreamer1-plugin-openh264 mozilla-openh264 powertop \
    libheif-freeworld heif-pixbuf-loader libheif-tools podman-compose && \
    dnf5 clean all && \
    ostree container commit
