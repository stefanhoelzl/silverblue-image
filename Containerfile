FROM quay.io/fedora/fedora-silverblue:latest

RUN rpm-ostree override remove noopenh264 && \
    rpm-ostree cleanup -m

RUN rpm-ostree install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm && \
    rpm-ostree cleanup -m

RUN rpm-ostree install openh264 gstreamer1-plugin-openh264 mozilla-openh264 powertop \
    libheif-freeworld heif-pixbuf-loader libheif-tools podman-compose && \
    rpm-ostree cleanup -m
