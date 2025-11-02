FROM quay.io/fedora/fedora-silverblue:latest

RUN rpm-ostree override remove noopenh264 --install openh264 || \
    rpm-ostree install gstreamer1-plugin-openh264 mozilla-openh264 powertop && \
    rpm-ostree cleanup -m
