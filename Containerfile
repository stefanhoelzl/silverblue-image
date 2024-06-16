FROM quay.io/fedora/fedora-silverblue:latest

COPY packages /packages
RUN rpm-ostree cliwrap install-to-root / && \
    rpm-ostree override remove noopenh264 && \
    # install additional packages
    rpm-ostree install \
        /packages/*.rpm \
        powertop openh264 mozilla-openh264  && \
    rm -rf /packages && \
    rpm-ostree cleanup -m
