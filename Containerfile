FROM quay.io/fedora/fedora-silverblue:39

COPY packages /packages
RUN rpm-ostree cliwrap install-to-root / && \
    # install additional packages
    rpm-ostree install \
        /packages/*.rpm \
        mozilla-openh264 && \
    rm -rf /packages && \
    rpm-ostree cleanup -m && \
    ostree container commit
