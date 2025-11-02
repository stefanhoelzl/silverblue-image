FROM quay.io/fedora/fedora-silverblue:latest

RUN rpm-ostree override remove noopenh264 && \
    rpm-ostree cleanup -m

RUN rpm-ostree install openh264 gstreamer1-plugin-openh264 mozilla-openh264 powertop && \
    rpm-ostree cleanup -m
