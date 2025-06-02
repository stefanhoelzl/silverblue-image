FROM quay.io/fedora/fedora-silverblue:latest

RUN rpm-ostree override remove noopenh264 --install openh264 --install gstreamer1-plugin-openh264 --install mozilla-openh264 && \
    rpm-ostree install powertop && \
    rpm-ostree cleanup -m
