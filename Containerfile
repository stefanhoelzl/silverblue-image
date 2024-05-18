FROM quay.io/fedora/fedora-silverblue:latest

COPY packages /packages
RUN rpm-ostree cliwrap install-to-root / && \
    # install additional packages
    rpm-ostree override remove noopenh264 --install openh264 --install mozilla-openh264 &&  \
    rpm-ostree install \
        /packages/*.rpm \
        powertop  && \
    rm -rf /packages && \
    rpm-ostree cleanup -m
